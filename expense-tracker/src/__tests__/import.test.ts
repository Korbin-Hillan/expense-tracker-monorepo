import { ImportService, ColumnMapping, ImportableTransaction } from '../services/importService';
import * as XLSX from 'xlsx';

describe('ImportService', () => {
  const sampleMapping: ColumnMapping = {
    date: 'Date',
    description: 'Description',
    amount: 'Amount',
    type: 'Type',
    category: 'Category',
    note: 'Note'
  };

  describe('parseCSV', () => {
    it('should parse a valid CSV file', async () => {
      const csvData = `Date,Description,Amount,Type,Category,Note
2024-01-15,Starbucks Coffee,-4.50,expense,Food,Morning coffee
2024-01-16,Salary Deposit,2500.00,income,Salary,Monthly salary
2024-01-17,Gas Station,-45.00,expense,Transportation,Fill up tank`;
      
      const buffer = Buffer.from(csvData);
      const result = await ImportService.parseCSV(buffer, sampleMapping);
      
      expect(result.totalRows).toBe(3);
      expect(result.validTransactions).toBe(3);
      expect(result.errors).toHaveLength(0);
      expect(result.preview).toHaveLength(3);
      
      // Check first transaction
      expect(result.preview[0]).toEqual({
        date: '2024-01-15',
        description: 'Starbucks Coffee',
        amount: 4.50,
        type: 'expense',
        category: 'Food',
        note: 'Morning coffee'
      });
    });

    it('should handle CSV with missing optional columns', async () => {
      const csvData = `Date,Description,Amount
2024-01-15,Starbucks Coffee,-4.50
2024-01-16,Walmart Grocery,-125.75`;
      
      const simpleMapping: ColumnMapping = {
        date: 'Date',
        description: 'Description',
        amount: 'Amount'
      };
      
      const buffer = Buffer.from(csvData);
      const result = await ImportService.parseCSV(buffer, simpleMapping);
      
      expect(result.totalRows).toBe(2);
      expect(result.validTransactions).toBe(2);
      expect(result.preview[0].category).toBe('Food'); // Auto-categorized by "Starbucks"
      expect(result.preview[1].category).toBe('Food'); // Auto-categorized by "Walmart"
    });

    it('should handle invalid data and report errors', async () => {
      const csvData = `Date,Description,Amount
invalid-date,Test Transaction,abc
2024-01-16,,50.00
2024-01-17,Valid Transaction,25.50`;
      
      const simpleMapping: ColumnMapping = {
        date: 'Date',
        description: 'Description',
        amount: 'Amount'
      };
      
      const buffer = Buffer.from(csvData);
      const result = await ImportService.parseCSV(buffer, simpleMapping);
      
      expect(result.totalRows).toBe(3);
      expect(result.validTransactions).toBe(1); // Only the last row is valid
      expect(result.errors.length).toBeGreaterThan(0);
    });
  });

  describe('parseExcel', () => {
    it('should parse a valid Excel file', async () => {
      // Create a simple Excel file in memory
      const ws = XLSX.utils.aoa_to_sheet([
        ['Date', 'Description', 'Amount', 'Type'],
        ['2024-01-15', 'Coffee Shop', -4.50, 'expense'],
        ['2024-01-16', 'Salary', 2500.00, 'income']
      ]);
      
      const wb = XLSX.utils.book_new();
      XLSX.utils.book_append_sheet(wb, ws, 'Sheet1');
      const buffer = XLSX.write(wb, { type: 'buffer', bookType: 'xlsx' });
      
      const mapping: ColumnMapping = {
        date: 'Date',
        description: 'Description',
        amount: 'Amount',
        type: 'Type'
      };
      
      const result = await ImportService.parseExcel(buffer, mapping);
      
      expect(result.totalRows).toBe(2);
      expect(result.validTransactions).toBe(2);
      expect(result.errors).toHaveLength(0);
    });
  });

  describe('categorizeTransaction', () => {
    it('should categorize food-related transactions', () => {
      const foodDescriptions = [
        'STARBUCKS COFFEE',
        'McDonald\'s Restaurant',
        'GROCERY STORE',
        'Food Mart'
      ];
      
      foodDescriptions.forEach(desc => {
        // Using any to access private method for testing
        const category = (ImportService as any).categorizeTransaction(desc);
        expect(category).toBe('Food');
      });
    });

    it('should categorize transportation-related transactions', () => {
      const transportDescriptions = [
        'SHELL GAS STATION',
        'UBER TRIP',
        'Metro Transit'
      ];
      
      transportDescriptions.forEach(desc => {
        const category = (ImportService as any).categorizeTransaction(desc);
        expect(category).toBe('Transportation');
      });
    });

    it('should default to Other for unknown transactions', () => {
      const category = (ImportService as any).categorizeTransaction('XYZ Corporation');
      expect(category).toBe('Other');
    });
  });

  describe('parseDate', () => {
    it('should parse various date formats', () => {
      const dateTests = [
        { input: '2024-01-15', expected: '2024-01-15' },
        { input: '01/15/2024', expected: '2024-01-15' },
        { input: '1/15/2024', expected: '2024-01-15' },
        { input: '01-15-2024', expected: '2024-01-15' }
      ];
      
      dateTests.forEach(test => {
        const result = (ImportService as any).parseDate(test.input);
        expect(result).toBe(test.expected);
      });
    });

    it('should return null for invalid dates', () => {
      const result = (ImportService as any).parseDate('invalid-date');
      expect(result).toBeNull();
    });
  });

  describe('parseAmount', () => {
    it('should parse various amount formats', () => {
      const amountTests = [
        { input: '25.50', expected: 25.50 },
        { input: '$25.50', expected: 25.50 },
        { input: '-25.50', expected: -25.50 },
        { input: '($25.50)', expected: -25.50 },
        { input: '1,250.75', expected: 1250.75 },
        { input: '$1,250.75', expected: 1250.75 }
      ];
      
      amountTests.forEach(test => {
        const result = (ImportService as any).parseAmount(test.input);
        expect(result).toBe(test.expected);
      });
    });

    it('should return NaN for invalid amounts', () => {
      const result = (ImportService as any).parseAmount('not-a-number');
      expect(result).toBeNaN();
    });
  });

  describe('detectDuplicates', () => {
    it('should detect potential duplicate transactions', () => {
      const newTransactions: ImportableTransaction[] = [
        {
          date: '2024-01-15',
          description: 'Starbucks Coffee',
          amount: 4.50,
          type: 'expense',
          category: 'Food'
        }
      ];

      const existingTransactions = [
        {
          _id: {} as any,
          userId: {} as any,
          type: 'expense' as const,
          amount: 4.50,
          category: 'Food',
          note: 'Starbucks Coffee',
          date: new Date('2024-01-15'),
          createdAt: new Date(),
          updatedAt: new Date()
        }
      ];

      const duplicates = ImportService.detectDuplicates(newTransactions, existingTransactions);
      expect(duplicates).toHaveLength(1);
    });

    it('should not flag transactions as duplicates if they are different', () => {
      const newTransactions: ImportableTransaction[] = [
        {
          date: '2024-01-15',
          description: 'Starbucks Coffee',
          amount: 4.50,
          type: 'expense',
          category: 'Food'
        }
      ];

      const existingTransactions = [
        {
          _id: {} as any,
          userId: {} as any,
          type: 'expense' as const,
          amount: 5.50, // Different amount
          category: 'Food',
          note: 'Starbucks Coffee',
          date: new Date('2024-01-15'),
          createdAt: new Date(),
          updatedAt: new Date()
        }
      ];

      const duplicates = ImportService.detectDuplicates(newTransactions, existingTransactions);
      expect(duplicates).toHaveLength(0);
    });
  });

  describe('convertToTransactionDoc', () => {
    it('should convert ImportableTransaction to TransactionDoc format', () => {
      const importTx: ImportableTransaction = {
        date: '2024-01-15',
        description: 'Test Transaction',
        amount: 25.50,
        type: 'expense',
        category: 'Food',
        note: 'Test note'
      };

      const userId = {} as any; // Mock ObjectId
      const result = ImportService.convertToTransactionDoc(importTx, userId);

      expect(result.userId).toBe(userId);
      expect(result.type).toBe('expense');
      expect(result.amount).toBe(25.50);
      expect(result.category).toBe('Food');
      expect(result.note).toBe('Test note');
      expect(result.date).toEqual(new Date('2024-01-15'));
    });
  });
});