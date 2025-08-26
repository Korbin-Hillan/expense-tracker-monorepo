import * as XLSX from 'xlsx';
import { parse } from 'csv-parse';
import { Readable } from 'stream';
import { TransactionDoc } from '../database/transactions.js';
import { ObjectId } from 'mongodb';

export interface ImportableTransaction {
  date: string;
  description: string;
  amount: number;
  type?: 'expense' | 'income';
  category?: string;
  note?: string;
}

export interface ImportResult {
  totalRows: number;
  validTransactions: number;
  errors: ImportError[];
  preview: ImportableTransaction[];
  duplicates: ImportableTransaction[];
}

export interface ImportError {
  row: number;
  field: string;
  message: string;
  data: any;
}

export interface ColumnMapping {
  date: string;
  description: string;
  amount: string;
  type?: string;
  category?: string;
  note?: string;
}

export class ImportService {
  /**
   * Parse CSV file buffer and extract transactions
   */
  static async parseCSV(fileBuffer: Buffer, mapping: ColumnMapping): Promise<ImportResult> {
    return new Promise((resolve, reject) => {
      const transactions: ImportableTransaction[] = [];
      const errors: ImportError[] = [];
      let rowIndex = 0;
      let totalRows = 0;

      const readable = Readable.from(fileBuffer);
      
      readable
        .pipe(parse({
          columns: true,
          skip_empty_lines: true,
          trim: true,
          relax_quotes: true,
          skip_records_with_error: false
        }))
        .on('data', (row) => {
          totalRows++;
          rowIndex++;
          
          try {
            const transaction = this.mapRowToTransaction(row, mapping, rowIndex);
            if (transaction) {
              transactions.push(transaction);
            }
          } catch (error) {
            errors.push({
              row: rowIndex,
              field: 'general',
              message: error instanceof Error ? error.message : 'Unknown parsing error',
              data: row
            });
          }
        })
        .on('error', (error) => {
          reject(new Error(`CSV parsing failed: ${error.message}`));
        })
        .on('end', () => {
          resolve({
            totalRows,
            validTransactions: transactions.length,
            errors,
            preview: transactions.slice(0, 10), // First 10 for preview
            duplicates: [] // Will be populated by duplicate detection
          });
        });
    });
  }

  /**
   * Parse Excel file buffer and extract transactions
   */
  static async parseExcel(fileBuffer: Buffer, mapping: ColumnMapping, sheetName?: string): Promise<ImportResult> {
    try {
      const workbook = XLSX.read(fileBuffer, { type: 'buffer' });
      
      // Use specified sheet or first sheet
      const targetSheetName = sheetName || workbook.SheetNames[0];
      const worksheet = workbook.Sheets[targetSheetName];
      
      if (!worksheet) {
        throw new Error(`Sheet "${targetSheetName}" not found`);
      }

      // Convert to JSON with header row
      const data = XLSX.utils.sheet_to_json(worksheet, { header: 1 });
      
      if (data.length < 2) {
        throw new Error('Excel file must contain at least a header row and one data row');
      }

      // Get headers and data rows
      const headers = data[0] as string[];
      const rows = data.slice(1);
      
      const transactions: ImportableTransaction[] = [];
      const errors: ImportError[] = [];
      
      rows.forEach((row, index) => {
        const rowIndex = index + 2; // +2 because we start from row 2 (after header)
        
        try {
          // Convert array to object using headers
          const rowObject: any = {};
          headers.forEach((header, colIndex) => {
            rowObject[header] = (row as any[])[colIndex];
          });
          
          const transaction = this.mapRowToTransaction(rowObject, mapping, rowIndex);
          if (transaction) {
            transactions.push(transaction);
          }
        } catch (error) {
          errors.push({
            row: rowIndex,
            field: 'general',
            message: error instanceof Error ? error.message : 'Unknown parsing error',
            data: row as any
          });
        }
      });

      return {
        totalRows: rows.length,
        validTransactions: transactions.length,
        errors,
        preview: transactions.slice(0, 10),
        duplicates: []
      };
    } catch (error) {
      throw new Error(`Excel parsing failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Map a row of data to a transaction using the provided column mapping
   */
  private static mapRowToTransaction(
    row: any, 
    mapping: ColumnMapping, 
    rowIndex: number
  ): ImportableTransaction | null {
    const errors: string[] = [];

    // Extract and validate date
    const dateValue = row[mapping.date];
    if (!dateValue) {
      throw new Error(`Date is required (row ${rowIndex})`);
    }
    
    const parsedDate = this.parseDate(dateValue);
    if (!parsedDate) {
      throw new Error(`Invalid date format: "${dateValue}" (row ${rowIndex})`);
    }

    // Extract and validate description
    const description = row[mapping.description];
    if (!description || typeof description !== 'string' || description.trim() === '') {
      throw new Error(`Description is required (row ${rowIndex})`);
    }

    // Extract and validate amount
    const amountValue = row[mapping.amount];
    if (amountValue === undefined || amountValue === null || amountValue === '') {
      throw new Error(`Amount is required (row ${rowIndex})`);
    }
    
    const amount = this.parseAmount(amountValue);
    if (isNaN(amount)) {
      throw new Error(`Invalid amount: "${amountValue}" (row ${rowIndex})`);
    }

    // Determine transaction type
    let type: 'expense' | 'income' = 'expense'; // Default to expense
    
    if (mapping.type && row[mapping.type]) {
      const typeValue = String(row[mapping.type]).toLowerCase().trim();
      if (typeValue.includes('income') || typeValue.includes('deposit') || typeValue.includes('credit')) {
        type = 'income';
      } else if (typeValue.includes('expense') || typeValue.includes('debit') || typeValue.includes('withdrawal')) {
        type = 'expense';
      }
    } else {
      // Infer from amount (positive = income, negative = expense)
      if (amount > 0) {
        type = 'income';
      } else {
        type = 'expense';
      }
    }

    // Extract optional fields
    const category = mapping.category && row[mapping.category] 
      ? this.categorizeTransaction(String(row[mapping.category]).trim()) 
      : this.categorizeTransaction(description);
    
    const note = mapping.note && row[mapping.note] 
      ? String(row[mapping.note]).trim() 
      : undefined;

    return {
      date: parsedDate,
      description: description.trim(),
      amount: Math.abs(amount), // Always store as positive
      type,
      category,
      note
    };
  }

  /**
   * Parse various date formats commonly found in bank statements
   */
  private static parseDate(dateValue: any): string | null {
    if (!dateValue) return null;

    // Handle Excel date numbers
    if (typeof dateValue === 'number') {
      const date = XLSX.SSF.parse_date_code(dateValue);
      if (date) {
        return new Date(date.y, date.m - 1, date.d).toISOString().split('T')[0];
      }
    }

    // Handle string dates
    const dateStr = String(dateValue).trim();
    
    // Common date formats in bank statements
    const dateFormats = [
      /^\d{4}-\d{2}-\d{2}$/, // YYYY-MM-DD
      /^\d{2}\/\d{2}\/\d{4}$/, // MM/DD/YYYY
      /^\d{1,2}\/\d{1,2}\/\d{4}$/, // M/D/YYYY
      /^\d{2}-\d{2}-\d{4}$/, // MM-DD-YYYY
      /^\d{1,2}-\d{1,2}-\d{4}$/, // M-D-YYYY
    ];

    let parsedDate: Date | null = null;

    // Try to parse with different formats
    if (dateFormats[0].test(dateStr)) { // YYYY-MM-DD
      parsedDate = new Date(dateStr);
    } else if (dateFormats[1].test(dateStr) || dateFormats[2].test(dateStr)) { // MM/DD/YYYY
      parsedDate = new Date(dateStr);
    } else if (dateFormats[3].test(dateStr) || dateFormats[4].test(dateStr)) { // MM-DD-YYYY
      const parts = dateStr.split('-');
      parsedDate = new Date(`${parts[2]}-${parts[0]}-${parts[1]}`);
    } else {
      // Try generic Date parsing
      parsedDate = new Date(dateStr);
    }

    if (parsedDate && !isNaN(parsedDate.getTime())) {
      return parsedDate.toISOString().split('T')[0];
    }

    return null;
  }

  /**
   * Parse amount values, handling various formats
   */
  private static parseAmount(amountValue: any): number {
    if (typeof amountValue === 'number') {
      return amountValue;
    }

    if (typeof amountValue !== 'string') {
      return NaN;
    }

    // Clean the amount string
    let cleanAmount = amountValue
      .replace(/[$,\s]/g, '') // Remove $, commas, spaces
      .replace(/[()]/g, '') // Remove parentheses
      .trim();

    // Handle negative indicators
    const isNegative = amountValue.includes('(') || amountValue.includes('-') || cleanAmount.startsWith('-');
    
    // Remove any remaining non-numeric characters except decimal point
    cleanAmount = cleanAmount.replace(/[^\d.-]/g, '');
    
    const amount = parseFloat(cleanAmount);
    return isNegative && amount > 0 ? -amount : amount;
  }

  /**
   * Auto-categorize transactions based on description
   */
  private static categorizeTransaction(description: string): string {
    const desc = description.toLowerCase();
    
    // Food & Dining
    if (desc.includes('restaurant') || desc.includes('cafe') || desc.includes('starbucks') || 
        desc.includes('mcdonald') || desc.includes('food') || desc.includes('dining') ||
        desc.includes('grocery') || desc.includes('supermarket') || desc.includes('walmart')) {
      return 'Food';
    }
    
    // Transportation
    if (desc.includes('gas') || desc.includes('fuel') || desc.includes('uber') || 
        desc.includes('lyft') || desc.includes('taxi') || desc.includes('parking') ||
        desc.includes('metro') || desc.includes('bus') || desc.includes('train')) {
      return 'Transportation';
    }
    
    // Shopping
    if (desc.includes('amazon') || desc.includes('target') || desc.includes('mall') ||
        desc.includes('store') || desc.includes('retail') || desc.includes('purchase')) {
      return 'Shopping';
    }
    
    // Bills & Utilities
    if (desc.includes('electric') || desc.includes('water') || desc.includes('internet') ||
        desc.includes('phone') || desc.includes('utility') || desc.includes('bill') ||
        desc.includes('payment') || desc.includes('service')) {
      return 'Bills';
    }
    
    // Entertainment
    if (desc.includes('movie') || desc.includes('theater') || desc.includes('netflix') ||
        desc.includes('spotify') || desc.includes('game') || desc.includes('entertainment')) {
      return 'Entertainment';
    }
    
    // Health
    if (desc.includes('pharmacy') || desc.includes('hospital') || desc.includes('doctor') ||
        desc.includes('medical') || desc.includes('health') || desc.includes('cvs')) {
      return 'Health';
    }
    
    // Default category
    return 'Other';
  }

  /**
   * Convert ImportableTransaction to TransactionDoc for database storage
   */
  static convertToTransactionDoc(
    transaction: ImportableTransaction, 
    userId: ObjectId
  ): Omit<TransactionDoc, '_id'> {
    const now = new Date();
    return {
      userId,
      type: transaction.type || 'expense',
      amount: transaction.amount,
      category: transaction.category || 'Other',
      note: transaction.note || transaction.description,
      date: new Date(transaction.date),
      createdAt: now,
      updatedAt: now
    };
  }

  /**
   * Detect potential duplicate transactions
   */
  static detectDuplicates(
    newTransactions: ImportableTransaction[],
    existingTransactions: TransactionDoc[]
  ): ImportableTransaction[] {
    const duplicates: ImportableTransaction[] = [];
    
    newTransactions.forEach(newTx => {
      const isDuplicate = existingTransactions.some(existing => 
        // Same date
        existing.date.toISOString().split('T')[0] === newTx.date &&
        // Same amount
        Math.abs(existing.amount - newTx.amount) < 0.01 &&
        // Similar description (fuzzy match)
        this.similarStrings(existing.note || '', newTx.description)
      );
      
      if (isDuplicate) {
        duplicates.push(newTx);
      }
    });
    
    return duplicates;
  }

  /**
   * Check if two strings are similar (for duplicate detection)
   */
  private static similarStrings(str1: string, str2: string, threshold = 0.8): boolean {
    const a = str1.toLowerCase().trim();
    const b = str2.toLowerCase().trim();
    
    if (a === b) return true;
    
    // Simple similarity check (Jaccard similarity)
    const wordsA = new Set(a.split(/\s+/));
    const wordsB = new Set(b.split(/\s+/));
    
    const intersection = new Set([...wordsA].filter(x => wordsB.has(x)));
    const union = new Set([...wordsA, ...wordsB]);
    
    return intersection.size / union.size >= threshold;
  }
}