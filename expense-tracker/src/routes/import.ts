import { Router } from "express";
import multer from "multer";
import { ObjectId } from "mongodb";
import { requireAppJWT } from "../middleware/auth.ts";
import { transactionsCollection } from "../database/transactions.ts";
import { ImportService, ColumnMapping } from "../services/importService.ts";

export const importRouter = Router();

// Configure multer for file uploads (memory storage for processing)
const upload = multer({ 
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB limit
  },
  fileFilter: (req, file, cb) => {
    const allowedTypes = [
      'text/csv',
      'application/vnd.ms-excel',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'text/plain'
    ];
    
    if (allowedTypes.includes(file.mimetype) || 
        file.originalname.endsWith('.csv') || 
        file.originalname.endsWith('.xlsx') ||
        file.originalname.endsWith('.xls')) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type. Only CSV and Excel files are allowed.'));
    }
  }
});

// POST /api/import/preview - Preview import data before committing
importRouter.post(
  "/api/import/preview",
  requireAppJWT,
  upload.single('file'),
  async (req, res) => {
    try {
      const userId = (req as any).userId as string;
      
      if (!req.file) {
        res.status(400).json({ error: "No file uploaded" });
        return;
      }

      // Parse column mapping from request body
      const mapping: ColumnMapping = {
        date: req.body.dateColumn || 'Date',
        description: req.body.descriptionColumn || 'Description',
        amount: req.body.amountColumn || 'Amount',
        type: req.body.typeColumn,
        category: req.body.categoryColumn,
        note: req.body.noteColumn
      };

      console.log(`📋 Import Preview: Processing ${req.file.originalname} for user ${userId}`);
      console.log(`📋 Column mapping:`, mapping);

      let importResult;
      
      // Parse based on file type
      if (req.file.mimetype.includes('csv') || req.file.originalname.endsWith('.csv')) {
        importResult = await ImportService.parseCSV(req.file.buffer, mapping);
      } else if (req.file.mimetype.includes('excel') || req.file.mimetype.includes('spreadsheet') || 
                 req.file.originalname.endsWith('.xlsx') || req.file.originalname.endsWith('.xls')) {
        const sheetName = req.body.sheetName;
        importResult = await ImportService.parseExcel(req.file.buffer, mapping, sheetName);
      } else {
        res.status(400).json({ error: "Unsupported file format" });
        return;
      }

      // Check for duplicates against existing transactions
      const col = await transactionsCollection();
      const existingTransactions = await col
        .find({ userId: new ObjectId(userId) })
        .sort({ date: -1 })
        .limit(1000) // Check last 1000 transactions for duplicates
        .toArray();

      const duplicates = ImportService.detectDuplicates(
        importResult.preview, 
        existingTransactions
      );

      importResult.duplicates = duplicates;

      console.log(`✅ Import Preview: Found ${importResult.validTransactions} valid transactions, ${importResult.errors.length} errors, ${duplicates.length} potential duplicates`);

      res.json(importResult);
    } catch (error) {
      console.error("Import preview error:", error);
      res.status(500).json({ 
        error: "Import preview failed", 
        message: error instanceof Error ? error.message : "Unknown error" 
      });
    }
  }
);

// POST /api/import/commit - Actually import the data
importRouter.post(
  "/api/import/commit",
  requireAppJWT,
  upload.single('file'),
  async (req, res) => {
    try {
      const userId = (req as any).userId as string;
      
      if (!req.file) {
        res.status(400).json({ error: "No file uploaded" });
        return;
      }

      // Parse settings
      const mapping: ColumnMapping = {
        date: req.body.dateColumn || 'Date',
        description: req.body.descriptionColumn || 'Description',
        amount: req.body.amountColumn || 'Amount',
        type: req.body.typeColumn,
        category: req.body.categoryColumn,
        note: req.body.noteColumn
      };

      const skipDuplicates = req.body.skipDuplicates === 'true';
      const overwriteDuplicates = req.body.overwriteDuplicates === 'true';

      console.log(`💾 Import Commit: Processing ${req.file.originalname} for user ${userId}`);
      console.log(`💾 Skip duplicates: ${skipDuplicates}, Overwrite: ${overwriteDuplicates}`);

      let importResult;
      
      // Parse the file
      if (req.file.mimetype.includes('csv') || req.file.originalname.endsWith('.csv')) {
        importResult = await ImportService.parseCSV(req.file.buffer, mapping);
      } else if (req.file.mimetype.includes('excel') || req.file.mimetype.includes('spreadsheet') ||
                 req.file.originalname.endsWith('.xlsx') || req.file.originalname.endsWith('.xls')) {
        const sheetName = req.body.sheetName;
        importResult = await ImportService.parseExcel(req.file.buffer, mapping, sheetName);
      } else {
        res.status(400).json({ error: "Unsupported file format" });
        return;
      }

      // Get all transactions from the import (not just preview)
      let allTransactions;
      if (req.file.mimetype.includes('csv') || req.file.originalname.endsWith('.csv')) {
        const fullResult = await ImportService.parseCSV(req.file.buffer, mapping);
        allTransactions = [...fullResult.preview, ...importResult.preview.slice(10)]; // This is a simplified approach
      } else {
        const fullResult = await ImportService.parseExcel(req.file.buffer, mapping, req.body.sheetName);
        allTransactions = [...fullResult.preview, ...importResult.preview.slice(10)]; // This is a simplified approach
      }

      // Handle duplicates
      const col = await transactionsCollection();
      const existingTransactions = await col
        .find({ userId: new ObjectId(userId) })
        .sort({ date: -1 })
        .limit(1000)
        .toArray();

      const duplicates = ImportService.detectDuplicates(allTransactions, existingTransactions);
      
      let transactionsToImport = allTransactions;
      
      if (skipDuplicates && duplicates.length > 0) {
        // Remove duplicates from import
        transactionsToImport = allTransactions.filter(tx => 
          !duplicates.some(dup => 
            dup.date === tx.date && 
            Math.abs(dup.amount - tx.amount) < 0.01 &&
            dup.description === tx.description
          )
        );
        console.log(`🔄 Skipping ${duplicates.length} duplicate transactions`);
      }

      // Convert to TransactionDoc format
      const transactionDocs = transactionsToImport.map(tx => 
        ImportService.convertToTransactionDoc(tx, new ObjectId(userId))
      );

      // Insert transactions
      let insertedCount = 0;
      if (transactionDocs.length > 0) {
        const result = await col.insertMany(transactionDocs);
        insertedCount = result.insertedCount;
      }

      console.log(`✅ Import Complete: Inserted ${insertedCount} transactions`);

      res.json({
        success: true,
        totalProcessed: allTransactions.length,
        inserted: insertedCount,
        duplicatesSkipped: skipDuplicates ? duplicates.length : 0,
        errors: importResult.errors,
        summary: {
          totalRows: importResult.totalRows,
          validTransactions: allTransactions.length,
          duplicatesFound: duplicates.length
        }
      });
    } catch (error) {
      console.error("Import commit error:", error);
      res.status(500).json({ 
        error: "Import failed", 
        message: error instanceof Error ? error.message : "Unknown error" 
      });
    }
  }
);

// GET /api/import/columns - Get available columns from uploaded file for mapping
importRouter.post(
  "/api/import/columns",
  requireAppJWT,
  upload.single('file'),
  async (req, res) => {
    try {
      if (!req.file) {
        res.status(400).json({ error: "No file uploaded" });
        return;
      }

      let columns: string[] = [];
      let sheets: string[] = [];

      if (req.file.mimetype.includes('csv') || req.file.originalname.endsWith('.csv')) {
        // For CSV, parse first few lines to get headers
        const csvData = req.file.buffer.toString('utf8');
        const lines = csvData.split('\n');
        if (lines.length > 0) {
          columns = lines[0].split(',').map(col => col.trim().replace(/"/g, ''));
        }
      } else if (req.file.mimetype.includes('excel') || req.file.mimetype.includes('spreadsheet') ||
                 req.file.originalname.endsWith('.xlsx') || req.file.originalname.endsWith('.xls')) {
        // For Excel, get sheet names and headers
        const workbook = require('xlsx').read(req.file.buffer, { type: 'buffer' });
        sheets = workbook.SheetNames;
        
        if (sheets.length > 0) {
          const firstSheet = workbook.Sheets[sheets[0]];
          const data = require('xlsx').utils.sheet_to_json(firstSheet, { header: 1 });
          if (data.length > 0) {
            columns = data[0] as string[];
          }
        }
      }

      res.json({
        columns,
        sheets,
        suggestedMapping: {
          date: findBestColumn(columns, ['date', 'transaction date', 'posted date', 'trans date', 'post date']),
          description: findBestColumn(columns, ['description', 'memo', 'details', 'transaction', 'merchant']),
          amount: findBestColumn(columns, ['amount', 'debit', 'credit', 'value', 'total', '$']),
          type: findBestColumn(columns, ['type', 'transaction type', 'debit/credit', 'dr/cr']),
          category: findBestColumn(columns, ['category', 'merchant category', 'classification']),
          note: findBestColumn(columns, ['note', 'memo', 'reference', 'check number'])
        }
      });
    } catch (error) {
      console.error("Column detection error:", error);
      res.status(500).json({ 
        error: "Failed to detect columns",
        message: error instanceof Error ? error.message : "Unknown error" 
      });
    }
  }
);

// Helper function to find best matching column
function findBestColumn(availableColumns: string[], searchTerms: string[]): string | undefined {
  const normalizedColumns = availableColumns.map(col => col.toLowerCase().trim());
  
  for (const term of searchTerms) {
    const match = normalizedColumns.find(col => col.includes(term));
    if (match) {
      return availableColumns[normalizedColumns.indexOf(match)];
    }
  }
  
  return undefined;
}

