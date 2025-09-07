import { ObjectId } from "mongodb";
import { ExpenseDoc, expensesCollection } from "../database/expenses.js";
import { RecurringExpenseDoc, recurringExpensesCollection } from "../database/recurringExpenses.js";

export class RecurringExpenseService {
  private static readonly COMMON_RECURRING_PATTERNS = [
    // Bills & Utilities
    /electric|electricity|power|utility/i,
    /water|sewer|waste/i,
    /gas|natural gas/i,
    /internet|wifi|broadband/i,
    /phone|mobile|cellular|verizon|att|tmobile/i,
    /cable|dish|satellite/i,
    
    // Subscriptions
    /netflix|hulu|amazon prime|disney|spotify|apple music/i,
    /subscription|monthly|yearly/i,
    
    // Rent & Housing
    /rent|mortgage|hoa|homeowners/i,
    /insurance|auto insurance|car insurance|health insurance/i,
    
    // Transportation
    /car payment|auto loan/i,
    
    // Other recurring patterns
    /gym|fitness|membership/i,
    /loan|payment/i
  ];

  static async detectAndCreateRecurringExpenses(
    expenses: ExpenseDoc[],
    userId: ObjectId
  ): Promise<void> {
    const expCol = await expensesCollection();
    const recCol = await recurringExpensesCollection();
    
    // Get all existing expenses for this user (last 6 months for analysis)
    const sixMonthsAgo = new Date();
    sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6);
    
    const allExpenses = await expCol
      .find({ 
        userId: userId,
        date: { $gte: sixMonthsAgo }
      })
      .sort({ date: 1 })
      .toArray();
    
    // Group expenses by similar descriptions
    const expenseGroups = this.groupExpensesByDescription(allExpenses);
    
    for (const [description, groupExpenses] of Object.entries(expenseGroups)) {
      if (groupExpenses.length >= 3) { // At least 3 occurrences
        const isRecurringPattern = this.isRecurringPattern(groupExpenses);
        const isCommonRecurring = this.COMMON_RECURRING_PATTERNS.some(pattern => 
          pattern.test(description)
        );
        
        if (isRecurringPattern || isCommonRecurring) {
          await this.createOrUpdateRecurringExpense(groupExpenses, userId);
        }
      }
    }
    
    // Link new expenses to existing recurring expenses
    await this.linkExpensesToRecurringExpenses(expenses, userId);
  }

  private static groupExpensesByDescription(expenses: ExpenseDoc[]): Record<string, ExpenseDoc[]> {
    const groups: Record<string, ExpenseDoc[]> = {};
    
    for (const expense of expenses) {
      const normalizedDesc = this.normalizeDescription(expense.description);
      
      // Find existing group with similar description
      let foundGroup = false;
      for (const [existingDesc, group] of Object.entries(groups)) {
        if (this.areSimilarDescriptions(normalizedDesc, existingDesc)) {
          group.push(expense);
          foundGroup = true;
          break;
        }
      }
      
      if (!foundGroup) {
        groups[normalizedDesc] = [expense];
      }
    }
    
    return groups;
  }

  private static normalizeDescription(description: string): string {
    return description
      .toLowerCase()
      .replace(/\d{4,}/g, '') // Remove long numbers (account numbers, etc.)
      .replace(/\b\d{1,2}\/\d{1,2}\b/g, '') // Remove dates
      .replace(/[#*\-_]+/g, ' ') // Replace special chars with spaces
      .replace(/\s+/g, ' ')
      .trim();
  }

  private static areSimilarDescriptions(desc1: string, desc2: string): boolean {
    const words1 = new Set(desc1.split(' ').filter(w => w.length > 2));
    const words2 = new Set(desc2.split(' ').filter(w => w.length > 2));
    
    const intersection = new Set([...words1].filter(x => words2.has(x)));
    const union = new Set([...words1, ...words2]);
    
    return intersection.size / union.size >= 0.6; // 60% similarity
  }

  private static isRecurringPattern(expenses: ExpenseDoc[]): boolean {
    if (expenses.length < 3) return false;
    
    // Sort by date
    expenses.sort((a, b) => a.date.getTime() - b.date.getTime());
    
    // Calculate intervals between expenses
    const intervals: number[] = [];
    for (let i = 1; i < expenses.length; i++) {
      const days = Math.floor(
        (expenses[i].date.getTime() - expenses[i-1].date.getTime()) / (1000 * 60 * 60 * 24)
      );
      intervals.push(days);
    }
    
    // Check for monthly pattern (28-32 days)
    const monthlyPattern = intervals.every(days => days >= 25 && days <= 35);
    if (monthlyPattern) return true;
    
    // Check for weekly pattern (6-8 days)
    const weeklyPattern = intervals.every(days => days >= 6 && days <= 8);
    if (weeklyPattern) return true;
    
    // Check for biweekly pattern (13-15 days)
    const biweeklyPattern = intervals.every(days => days >= 13 && days <= 15);
    if (biweeklyPattern) return true;
    
    return false;
  }

  private static async createOrUpdateRecurringExpense(
    expenses: ExpenseDoc[],
    userId: ObjectId
  ): Promise<void> {
    const recCol = await recurringExpensesCollection();
    const expCol = await expensesCollection();
    
    const firstExpense = expenses[0];
    const normalizedName = this.normalizeDescription(firstExpense.description);
    
    // Check if this recurring expense already exists
    const existing = await recCol.findOne({
      userId: userId,
      name: normalizedName
    });
    
    const amounts = expenses.map(e => e.amount);
    const averageAmount = amounts.reduce((a, b) => a + b, 0) / amounts.length;
    const minAmount = Math.min(...amounts);
    const maxAmount = Math.max(...amounts);
    
    const descriptions = [...new Set(expenses.map(e => e.description))];
    const frequency = this.determineFrequency(expenses);
    
    const recurringExpenseData: Partial<RecurringExpenseDoc> = {
      userId: userId,
      name: normalizedName,
      category: firstExpense.category,
      averageAmount: averageAmount,
      frequency: frequency,
      firstDetected: expenses[0].date,
      lastSeen: expenses[expenses.length - 1].date,
      occurrenceCount: expenses.length,
      isActive: true,
      patterns: {
        descriptions: descriptions,
        amountRange: { min: minAmount, max: maxAmount },
        dayOfMonth: frequency === 'monthly' ? expenses[0].date.getDate() : undefined,
        dayOfWeek: frequency === 'weekly' ? expenses[0].date.getDay() : undefined
      },
      updatedAt: new Date()
    };

    let recurringExpenseId: ObjectId;
    
    if (existing) {
      // Update existing
      await recCol.updateOne(
        { _id: existing._id },
        { $set: recurringExpenseData }
      );
      recurringExpenseId = existing._id!;
    } else {
      // Create new
      const result = await recCol.insertOne({
        ...recurringExpenseData,
        createdAt: new Date()
      } as RecurringExpenseDoc);
      recurringExpenseId = result.insertedId;
    }
    
    // Link all expenses to this recurring expense
    const expenseIds = expenses.map(e => e._id!);
    await expCol.updateMany(
      { _id: { $in: expenseIds } },
      { 
        $set: { 
          recurringExpenseId: recurringExpenseId,
          isRecurring: true,
          updatedAt: new Date()
        }
      }
    );
  }

  private static determineFrequency(expenses: ExpenseDoc[]): "monthly" | "weekly" | "biweekly" | "yearly" | "daily" {
    if (expenses.length < 2) return "monthly";
    
    expenses.sort((a, b) => a.date.getTime() - b.date.getTime());
    
    const intervals: number[] = [];
    for (let i = 1; i < expenses.length; i++) {
      const days = Math.floor(
        (expenses[i].date.getTime() - expenses[i-1].date.getTime()) / (1000 * 60 * 60 * 24)
      );
      intervals.push(days);
    }
    
    const avgInterval = intervals.reduce((a, b) => a + b, 0) / intervals.length;
    
    if (avgInterval <= 2) return "daily";
    if (avgInterval >= 6 && avgInterval <= 8) return "weekly";
    if (avgInterval >= 13 && avgInterval <= 15) return "biweekly";
    if (avgInterval >= 25 && avgInterval <= 35) return "monthly";
    if (avgInterval >= 350 && avgInterval <= 375) return "yearly";
    
    return "monthly"; // default
  }

  private static async linkExpensesToRecurringExpenses(
    newExpenses: ExpenseDoc[],
    userId: ObjectId
  ): Promise<void> {
    const recCol = await recurringExpensesCollection();
    const expCol = await expensesCollection();
    
    // Get all active recurring expenses for this user
    const recurringExpenses = await recCol
      .find({ userId: userId, isActive: true })
      .toArray();
    
    for (const expense of newExpenses) {
      if (expense.recurringExpenseId) continue; // Already linked
      
      // Try to match with existing recurring expenses
      for (const recurring of recurringExpenses) {
        if (this.expenseMatchesRecurringPattern(expense, recurring)) {
          await expCol.updateOne(
            { _id: expense._id },
            { 
              $set: { 
                recurringExpenseId: recurring._id,
                isRecurring: true,
                updatedAt: new Date()
              }
            }
          );
          
          // Update recurring expense stats
          await recCol.updateOne(
            { _id: recurring._id },
            { 
              $set: { 
                lastSeen: expense.date,
                updatedAt: new Date()
              },
              $inc: { occurrenceCount: 1 }
            }
          );
          break;
        }
      }
    }
  }

  private static expenseMatchesRecurringPattern(
    expense: ExpenseDoc,
    recurring: RecurringExpenseDoc
  ): boolean {
    // Check category match
    if (expense.category !== recurring.category) return false;
    
    // Check amount is within range
    const { min, max } = recurring.patterns.amountRange;
    if (expense.amount < min * 0.8 || expense.amount > max * 1.2) return false;
    
    // Check description similarity
    const normalizedExpenseDesc = this.normalizeDescription(expense.description);
    const similarToPatterns = recurring.patterns.descriptions.some(pattern =>
      this.areSimilarDescriptions(normalizedExpenseDesc, this.normalizeDescription(pattern))
    );
    
    return similarToPatterns;
  }
}