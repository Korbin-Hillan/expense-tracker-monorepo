import { ExportService, ExportableTransaction } from '../services/exportService';
import { readFileSync, existsSync, unlinkSync } from 'fs';

describe('ExportService', () => {
  const mockTransactions: ExportableTransaction[] = [
    {
      id: '507f1f77bcf86cd799439011',
      type: 'expense',
      amount: 50.25,
      category: 'Food',
      note: 'Lunch at restaurant',
      date: '2024-01-15',
      createdAt: '2024-01-15T12:00:00.000Z',
      updatedAt: '2024-01-15T12:00:00.000Z'
    },
    {
      id: '507f1f77bcf86cd799439012',
      type: 'income',
      amount: 2500.00,
      category: 'Salary',
      note: 'Monthly salary',
      date: '2024-01-01',
      createdAt: '2024-01-01T09:00:00.000Z',
      updatedAt: '2024-01-01T09:00:00.000Z'
    }
  ];

  describe('generateCSV', () => {
    it('should generate a CSV file with correct headers and data', async () => {
      const csvPath = await ExportService.generateCSV(mockTransactions, 'test.csv');
      
      expect(existsSync(csvPath)).toBe(true);
      
      const csvContent = readFileSync(csvPath, 'utf8');
      expect(csvContent).toContain('Transaction ID,Type,Amount,Category,Note,Date,Created At,Updated At');
      expect(csvContent).toContain('507f1f77bcf86cd799439011,expense,50.25,Food,Lunch at restaurant,2024-01-15');
      expect(csvContent).toContain('507f1f77bcf86cd799439012,income,2500,Salary,Monthly salary,2024-01-01');
      
      // Clean up
      unlinkSync(csvPath);
    });
  });

  describe('generateExcel', () => {
    it('should generate an Excel file', () => {
      const excelPath = ExportService.generateExcel(mockTransactions, 'test.xlsx');
      
      expect(existsSync(excelPath)).toBe(true);
      
      const stats = readFileSync(excelPath);
      expect(stats.length).toBeGreaterThan(0);
      
      // Clean up
      unlinkSync(excelPath);
    });
  });

  describe('generateSummaryStats', () => {
    it('should calculate correct summary statistics', () => {
      const stats = ExportService.generateSummaryStats(mockTransactions);
      
      expect(stats.totalTransactions).toBe(2);
      expect(stats.totalIncome).toBe(2500.00);
      expect(stats.totalExpenses).toBe(50.25);
      expect(stats.netAmount).toBe(2449.75);
      expect(stats.categorySummary).toEqual({
        'Food': { count: 1, total: 50.25 },
        'Salary': { count: 1, total: 2500.00 }
      });
      expect(stats.dateRange.from).toBe('2024-01-01');
      expect(stats.dateRange.to).toBe('2024-01-15');
    });

    it('should handle empty transactions array', () => {
      const stats = ExportService.generateSummaryStats([]);
      
      expect(stats.totalTransactions).toBe(0);
      expect(stats.totalIncome).toBe(0);
      expect(stats.totalExpenses).toBe(0);
      expect(stats.netAmount).toBe(0);
      expect(stats.categorySummary).toEqual({});
      expect(stats.dateRange.from).toBe('N/A');
      expect(stats.dateRange.to).toBe('N/A');
    });
  });

  describe('prepareTransactionsForExport', () => {
    it('should convert transaction documents to exportable format', () => {
      const mockDoc = {
        _id: { toHexString: () => '507f1f77bcf86cd799439011' },
        type: 'expense' as const,
        amount: 50.25,
        category: 'Food',
        note: 'Lunch',
        date: new Date('2024-01-15T12:00:00.000Z'),
        createdAt: new Date('2024-01-15T12:00:00.000Z'),
        updatedAt: new Date('2024-01-15T12:00:00.000Z'),
        userId: { toHexString: () => 'user123' }
      };

      const result = ExportService.prepareTransactionsForExport([mockDoc as any]);
      
      expect(result).toHaveLength(1);
      expect(result[0]).toEqual({
        id: '507f1f77bcf86cd799439011',
        type: 'expense',
        amount: 50.25,
        category: 'Food',
        note: 'Lunch',
        date: '2024-01-15',
        createdAt: '2024-01-15T12:00:00.000Z',
        updatedAt: '2024-01-15T12:00:00.000Z'
      });
    });
  });
});