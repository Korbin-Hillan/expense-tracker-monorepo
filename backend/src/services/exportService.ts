import * as XLSX from 'xlsx';
import * as createCsvWriter from 'csv-writer';
import { tmpdir } from 'os';
import { join } from 'path';
import { TransactionDoc } from '../database/transactions.js';

export interface ExportableTransaction {
  id: string;
  type: 'expense' | 'income';
  amount: number;
  category: string;
  note?: string;
  date: string;
  createdAt: string;
  updatedAt: string;
}

export class ExportService {
  /**
   * Convert transaction documents to exportable format
   */
  static prepareTransactionsForExport(transactions: TransactionDoc[]): ExportableTransaction[] {
    return transactions.map(tx => ({
      id: tx._id!.toHexString(),
      type: tx.type,
      amount: (tx as any).amountCents ? (tx as any).amountCents / 100 : (tx as any).amount,
      category: tx.category,
      note: tx.note || '',
      date: tx.date.toISOString().split('T')[0], // YYYY-MM-DD format
      createdAt: tx.createdAt.toISOString(),
      updatedAt: tx.updatedAt.toISOString()
    }));
  }

  /**
   * Generate CSV file and return file path
   */
  static async generateCSV(transactions: ExportableTransaction[], filename?: string): Promise<string> {
    const csvFilename = filename || `transactions_${Date.now()}.csv`;
    const csvPath = join(tmpdir(), csvFilename);

    const csvWriter = createCsvWriter.createObjectCsvWriter({
      path: csvPath,
      header: [
        { id: 'id', title: 'Transaction ID' },
        { id: 'type', title: 'Type' },
        { id: 'amount', title: 'Amount' },
        { id: 'category', title: 'Category' },
        { id: 'note', title: 'Note' },
        { id: 'date', title: 'Date' },
        { id: 'createdAt', title: 'Created At' },
        { id: 'updatedAt', title: 'Updated At' }
      ]
    });

    await csvWriter.writeRecords(transactions);
    return csvPath;
  }

  /**
   * Generate Excel file and return file path
   */
  static generateExcel(transactions: ExportableTransaction[], filename?: string): string {
    const excelFilename = filename || `transactions_${Date.now()}.xlsx`;
    const excelPath = join(tmpdir(), excelFilename);

    // Create a new workbook
    const workbook = XLSX.utils.book_new();

    // Convert transactions to worksheet data
    const worksheetData = [
      ['Transaction ID', 'Type', 'Amount', 'Category', 'Note', 'Date', 'Created At', 'Updated At'],
      ...transactions.map(tx => [
        tx.id,
        tx.type,
        tx.amount,
        tx.category,
        tx.note || '',
        tx.date,
        tx.createdAt,
        tx.updatedAt
      ])
    ];

    // Create worksheet
    const worksheet = XLSX.utils.aoa_to_sheet(worksheetData);

    // Auto-size columns
    const columnWidths = [
      { wch: 25 }, // Transaction ID
      { wch: 10 }, // Type
      { wch: 12 }, // Amount
      { wch: 15 }, // Category
      { wch: 30 }, // Note
      { wch: 12 }, // Date
      { wch: 20 }, // Created At
      { wch: 20 }  // Updated At
    ];
    worksheet['!cols'] = columnWidths;

    // Add worksheet to workbook
    XLSX.utils.book_append_sheet(workbook, worksheet, 'Transactions');

    // Write file
    XLSX.writeFile(workbook, excelPath);
    return excelPath;
  }

  /**
   * Get summary statistics for transactions
   */
  static generateSummaryStats(transactions: ExportableTransaction[]): {
    totalTransactions: number;
    totalIncome: number;
    totalExpenses: number;
    netAmount: number;
    categorySummary: { [category: string]: { count: number; total: number } };
    dateRange: { from: string; to: string };
  } {
    const totalTransactions = transactions.length;
    let totalIncome = 0;
    let totalExpenses = 0;
    const categorySummary: { [category: string]: { count: number; total: number } } = {};
    
    let earliestDate = '';
    let latestDate = '';

    transactions.forEach(tx => {
      if (tx.type === 'income') {
        totalIncome += tx.amount;
      } else {
        totalExpenses += tx.amount;
      }

      // Category summary
      if (!categorySummary[tx.category]) {
        categorySummary[tx.category] = { count: 0, total: 0 };
      }
      categorySummary[tx.category].count += 1;
      categorySummary[tx.category].total += tx.amount;

      // Date range
      if (!earliestDate || tx.date < earliestDate) {
        earliestDate = tx.date;
      }
      if (!latestDate || tx.date > latestDate) {
        latestDate = tx.date;
      }
    });

    const netAmount = totalIncome - totalExpenses;

    return {
      totalTransactions,
      totalIncome,
      totalExpenses,
      netAmount,
      categorySummary,
      dateRange: {
        from: earliestDate || 'N/A',
        to: latestDate || 'N/A'
      }
    };
  }
}
