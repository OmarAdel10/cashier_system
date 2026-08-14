class ExpenseItemInput {
  const ExpenseItemInput({
    required this.barcode,
    required this.name,
    required this.quantity,
    required this.costPiastres,
  });

  final String barcode;
  final String name;
  final int quantity;
  final int costPiastres;
}

sealed class ExpensesEvent {
  const ExpensesEvent();
}

class CreateExpense extends ExpensesEvent {
  const CreateExpense({
    required this.username,
    required this.items,
    this.name = '',
  });

  final String username;
  final List<ExpenseItemInput> items;
  final String name;
}
