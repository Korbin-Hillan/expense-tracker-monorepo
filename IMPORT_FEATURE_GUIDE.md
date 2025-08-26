# Import Feature Implementation Guide

## Overview
I've successfully implemented a comprehensive data import feature that allows users to import transaction data from bank and credit card statements in CSV and Excel formats.

## Backend Implementation

### New Dependencies Added
```json
{
  "@types/multer": "^2.0.0",
  "multer": "^2.0.2",
  "csv-parse": "^6.1.0"
}
```

### New API Endpoints
1. **Column Detection**: `POST /api/import/columns`
2. **Import Preview**: `POST /api/import/preview`
3. **Import Commit**: `POST /api/import/commit`

### Import Flow

#### 1. Column Detection (`/api/import/columns`)
- Analyzes uploaded file to detect available columns
- For CSV: Parses headers from first row
- For Excel: Extracts sheet names and column headers
- Returns suggested column mappings based on common patterns

**Response Format:**
```json
{
  "columns": ["Date", "Description", "Amount", "Type"],
  "sheets": ["Sheet1", "Transactions"],
  "suggestedMapping": {
    "date": "Date",
    "description": "Description", 
    "amount": "Amount",
    "type": "Type",
    "category": null,
    "note": null
  }
}
```

#### 2. Import Preview (`/api/import/preview`)
- Parses file using provided column mapping
- Validates data and reports errors
- Auto-categorizes transactions
- Detects potential duplicates
- Returns preview of first 10 transactions

**Request Parameters:**
- `file`: Uploaded CSV/Excel file
- `dateColumn`: Column name for dates
- `descriptionColumn`: Column name for descriptions
- `amountColumn`: Column name for amounts
- `typeColumn`: (Optional) Column name for transaction type
- `categoryColumn`: (Optional) Column name for categories
- `noteColumn`: (Optional) Column name for notes
- `sheetName`: (Optional) Excel sheet name

**Response Format:**
```json
{
  "totalRows": 100,
  "validTransactions": 95,
  "errors": [
    {
      "row": 5,
      "field": "date",
      "message": "Invalid date format",
      "data": {}
    }
  ],
  "preview": [
    {
      "date": "2024-01-15",
      "description": "Starbucks Coffee",
      "amount": 4.50,
      "type": "expense",
      "category": "Food",
      "note": "Morning coffee"
    }
  ],
  "duplicates": []
}
```

#### 3. Import Commit (`/api/import/commit`)
- Actually imports the data into the database
- Supports duplicate handling (skip or overwrite)
- Returns import summary

**Response Format:**
```json
{
  "success": true,
  "totalProcessed": 100,
  "inserted": 95,
  "duplicatesSkipped": 5,
  "errors": [],
  "summary": {
    "totalRows": 100,
    "validTransactions": 95,
    "duplicatesFound": 5
  }
}
```

### Smart Features

#### Auto-Categorization
The system automatically categorizes transactions based on description keywords:
- **Food**: Starbucks, McDonald's, grocery, supermarket, restaurant, etc.
- **Transportation**: Gas, fuel, Uber, Lyft, parking, metro, etc.
- **Shopping**: Amazon, Target, mall, store, retail, etc.
- **Bills**: Electric, water, internet, phone, utility, etc.
- **Entertainment**: Movie, theater, Netflix, Spotify, etc.
- **Health**: Pharmacy, hospital, doctor, medical, CVS, etc.

#### Date Format Support
Supports multiple date formats commonly used by banks:
- `YYYY-MM-DD` (ISO format)
- `MM/DD/YYYY` (US format)
- `M/D/YYYY` (US short format)
- `MM-DD-YYYY` (US dash format)
- Excel date numbers

#### Amount Format Support
Handles various amount representations:
- `25.50` (standard decimal)
- `$25.50` (with currency symbol)
- `-25.50` (negative)
- `($25.50)` (parentheses for negative)
- `1,250.75` (with thousand separators)

#### Duplicate Detection
Identifies potential duplicates by comparing:
- Same date
- Same amount (within 1 cent)
- Similar descriptions (fuzzy matching)

### File Support

#### CSV Files
- Must have header row
- Supports various delimiters (auto-detected)
- Handles quoted fields
- Up to 10MB file size

#### Excel Files
- Supports .xlsx and .xls formats
- Multiple sheet support
- Header row detection
- Up to 10MB file size

## iOS Frontend Implementation

### New UI Components

#### 1. ImportDataSheet
Main import interface with:
- File picker for CSV/Excel files
- File format support information
- Import tips and guidelines

#### 2. ColumnMappingSheet  
Column mapping interface with:
- Automatic column detection
- Suggested mappings
- Required/optional field configuration
- Import settings (skip duplicates)

#### 3. ImportPreviewSheet
Preview and commit interface with:
- Transaction preview (first 10)
- Import summary statistics
- Error reporting
- Final import confirmation
- Success screen with results

### User Experience Flow

1. **File Selection**: User taps import button (↓) and selects CSV/Excel file
2. **File Analysis**: App analyzes file and detects columns automatically
3. **Column Mapping**: User reviews and adjusts column mappings
4. **Preview**: User previews transactions and sees summary
5. **Import**: User commits import and sees success confirmation
6. **Refresh**: Transaction list automatically refreshes

### Import Button Locations
- **Recent View**: Import button (↓) in top-left toolbar
- **Reports View**: Available via toolbar (planned)

### Error Handling
- File format validation
- Network error handling
- Data validation errors
- User-friendly error messages
- Retry mechanisms

## Sample Bank Statement Format

Created sample file: `/Users/korbinhillan/Desktop/expense-backend/sample_bank_statement.csv`

```csv
Date,Description,Debit,Credit,Balance
01/15/2024,STARBUCKS STORE #12345,4.50,,2495.50
01/16/2024,DIRECT DEPOSIT PAYROLL,,2500.00,4995.50
01/17/2024,SHELL GAS STATION #9876,45.00,,4950.50
```

This format demonstrates:
- Date in MM/DD/YYYY format
- Separate Debit/Credit columns
- Running balance column
- Real-world merchant names

## Testing

### Backend Tests
- ✅ CSV parsing with various formats
- ✅ Excel file parsing
- ✅ Date format parsing (multiple formats)
- ✅ Amount format parsing (currency, negatives, etc.)
- ✅ Auto-categorization logic
- ✅ Duplicate detection algorithm
- ✅ Error handling and validation
- ✅ Data conversion functions

### Manual Testing Checklist
1. Upload CSV file with standard format
2. Upload Excel file with multiple sheets
3. Test column mapping with different layouts
4. Verify auto-categorization accuracy
5. Test duplicate detection
6. Try files with errors/invalid data
7. Test various date and amount formats
8. Verify transactions appear in Recent view

## Security & Validation

### File Upload Security
- File type validation (CSV/Excel only)
- File size limits (10MB max)
- Memory-based processing (no disk storage)
- Authenticated endpoints only

### Data Validation
- Required field validation
- Date format validation
- Numeric amount validation
- Transaction type validation
- User isolation (can only import to own account)

### Error Recovery
- Graceful handling of malformed files
- Partial import support
- Rollback on critical errors
- Detailed error reporting

## Performance Considerations

### Backend
- Streaming CSV parser for large files
- Memory-efficient Excel processing
- Bulk database operations
- Transaction batching

### iOS
- Progress indicators for long operations
- Background processing
- Memory management for large files
- Responsive UI during imports

## Common Bank Statement Formats

### Supported Formats
1. **Chase Bank**: Date, Description, Amount, Type, Balance
2. **Bank of America**: Date, Description, Amount, Running Bal
3. **Wells Fargo**: Date, Amount, *, *, Description
4. **Capital One**: Transaction Date, Description, Debit, Credit
5. **American Express**: Date, Description, Amount
6. **Generic CSV**: Any format with date, description, amount columns

### Format Tips for Users
1. Use official bank export when possible
2. Ensure file has column headers
3. Remove summary rows/totals
4. Use CSV format for best compatibility
5. Check date format matches expected format

## Troubleshooting

### Common Issues
1. **"No columns detected"**: File missing headers or corrupted
2. **"Invalid date format"**: Dates not in expected format  
3. **"Amount parsing failed"**: Non-numeric amounts in amount column
4. **"File too large"**: Reduce file size or split into smaller files
5. **"Duplicate transactions"**: Enable "Skip Duplicates" option

### Import Best Practices
1. Download statements in CSV format when possible
2. Import one month at a time for better performance
3. Review preview carefully before committing
4. Use descriptive file names for organization
5. Keep original files for reference

## Future Enhancements

Potential improvements:
1. **QIF/OFX Support**: Support Quicken/Money formats
2. **Bank Integration**: Direct API connections to banks
3. **OCR Support**: Extract data from PDF statements  
4. **Scheduling**: Automated periodic imports
5. **Mapping Templates**: Save column mappings for reuse
6. **Advanced Categorization**: Machine learning-based categorization
7. **Import History**: Track and manage previous imports
8. **Bulk Operations**: Import multiple files at once

The import feature is now fully functional and ready for production use!