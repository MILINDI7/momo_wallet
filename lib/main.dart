import 'package:flutter/material.dart';

void main() {
  runApp(const MomoWalletApp());
}

// ============================================================
// APP
// ============================================================

class MomoWalletApp extends StatelessWidget {
  const MomoWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MoMo Wallet',
      theme: ThemeData(
        colorSchemeSeed: Colors.yellow,
        useMaterial3: true,
      ),
      home: const WalletScreen(),
    );
  }
}

// ============================================================
// TRANSACTION MODEL
// ============================================================

enum TransactionType {
  moneyIn,
  moneyOut,
}

class WalletTransaction {
  WalletTransaction({
    required this.description,
    required this.amount,
    required this.type,
    required this.date,
  });

  final String description;
  final int amount;
  final TransactionType type;
  final DateTime date;
}

// ============================================================
// WALLET SCREEN
// ============================================================

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  static const int startingBalance = 10000;

  String selectedFilter = 'All';

  final List<WalletTransaction> transactions = [
    WalletTransaction(
      description: 'Received from Alice',
      amount: 5000,
      type: TransactionType.moneyIn,
      date: DateTime(2026, 10, 25, 9, 30),
    ),
    WalletTransaction(
      description: 'Sent to 0788123456',
      amount: 2000,
      type: TransactionType.moneyOut,
      date: DateTime(2026, 10, 25, 12, 10),
    ),
    WalletTransaction(
      description: 'Cash out',
      amount: 1000,
      type: TransactionType.moneyOut,
      date: DateTime(2026, 10, 26, 14, 20),
    ),
  ];

  // ----------------------------------------------------------
  // CALCULATIONS
  // ----------------------------------------------------------

  int get currentBalance {
    int balance = startingBalance;

    for (final transaction in transactions) {
      if (transaction.type == TransactionType.moneyIn) {
        balance += transaction.amount;
      } else {
        balance -= transaction.amount;
      }
    }

    return balance;
  }

  int get totalIn {
    int total = 0;

    for (final transaction in transactions) {
      if (transaction.type == TransactionType.moneyIn) {
        total += transaction.amount;
      }
    }

    return total;
  }

  int get totalOut {
    int total = 0;

    for (final transaction in transactions) {
      if (transaction.type == TransactionType.moneyOut) {
        total += transaction.amount;
      }
    }

    return total;
  }

  int get lowestBalance {
    int balance = startingBalance;
    int lowest = startingBalance;

    for (final transaction in transactions) {
      if (transaction.type == TransactionType.moneyIn) {
        balance += transaction.amount;
      } else {
        balance -= transaction.amount;
      }

      if (balance < lowest) {
        lowest = balance;
      }
    }

    return lowest;
  }

  List<WalletTransaction> get filteredTransactions {
    final newestFirst = transactions.reversed.toList();

    if (selectedFilter == 'IN') {
      return newestFirst
          .where((transaction) =>
      transaction.type == TransactionType.moneyIn)
          .toList();
    }

    if (selectedFilter == 'OUT') {
      return newestFirst
          .where((transaction) =>
      transaction.type == TransactionType.moneyOut)
          .toList();
    }

    return newestFirst;
  }

  // ----------------------------------------------------------
  // RECEIVE
  // ----------------------------------------------------------

  Future<void> openReceiveScreen() async {
    final result = await Navigator.push<WalletTransaction>(
      context,
      MaterialPageRoute(
        builder: (context) => const ReceiveMoneyScreen(),
      ),
    );

    if (result != null) {
      setState(() {
        transactions.add(result);
      });
    }
  }

  // ----------------------------------------------------------
  // SEND
  // ----------------------------------------------------------

  Future<void> openSendScreen() async {
    final result = await Navigator.push<WalletTransaction>(
      context,
      MaterialPageRoute(
        builder: (context) => SendMoneyScreen(
          availableBalance: currentBalance,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        transactions.add(result);
      });
    }
  }

  // ----------------------------------------------------------
  // CASH OUT
  // ----------------------------------------------------------

  Future<void> openCashOutScreen() async {
    final result = await Navigator.push<WalletTransaction>(
      context,
      MaterialPageRoute(
        builder: (context) => CashOutScreen(
          availableBalance: currentBalance,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        transactions.add(result);
      });
    }
  }

  // ----------------------------------------------------------
  // DELETE + HISTORY VALIDATION
  // ----------------------------------------------------------

  bool canDeleteTransaction(WalletTransaction transaction) {
    final copy = List<WalletTransaction>.from(transactions);

    copy.remove(transaction);

    int balance = startingBalance;

    for (final item in copy) {
      if (item.type == TransactionType.moneyIn) {
        balance += item.amount;
      } else {
        balance -= item.amount;
      }

      if (balance < 0) {
        return false;
      }
    }

    return true;
  }

  void deleteTransaction(WalletTransaction transaction) {
    if (!canDeleteTransaction(transaction)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot delete: balance would go below 0 in transaction history.',
          ),
        ),
      );

      return;
    }

    final position = transactions.indexOf(transaction);

    setState(() {
      transactions.remove(transaction);
    });

    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${transaction.description} deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              transactions.insert(position, transaction);
            });
          },
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // UI HELPERS
  // ----------------------------------------------------------

  String formatMoney(int amount) {
    final text = amount.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) {
        buffer.write(',');
      }

      buffer.write(text[i]);
    }

    return '${buffer.toString()} RWF';
  }

  Widget statisticCard(
      String title,
      int amount,
      IconData icon,
      ) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatMoney(amount),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // BUILD
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final shownTransactions = filteredTransactions;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MoMo Wallet',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // BALANCE CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.yellow.shade600,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Available Balance',
                          style: TextStyle(
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatMoney(currentBalance),
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ACTION BUTTONS
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: openSendScreen,
                          icon: const Icon(Icons.send),
                          label: const Text('Send'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: openReceiveScreen,
                          icon: const Icon(Icons.download),
                          label: const Text('Receive'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: openCashOutScreen,
                          icon: const Icon(Icons.money),
                          label: const Text('Cash out'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Statistics',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      statisticCard(
                        'Total IN',
                        totalIn,
                        Icons.arrow_downward,
                      ),
                      statisticCard(
                        'Total OUT',
                        totalOut,
                        Icons.arrow_upward,
                      ),
                      statisticCard(
                        'Lowest',
                        lowestBalance,
                        Icons.trending_down,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Transactions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: selectedFilter == 'All',
                        onSelected: (_) {
                          setState(() {
                            selectedFilter = 'All';
                          });
                        },
                      ),
                      ChoiceChip(
                        label: const Text('IN'),
                        selected: selectedFilter == 'IN',
                        onSelected: (_) {
                          setState(() {
                            selectedFilter = 'IN';
                          });
                        },
                      ),
                      ChoiceChip(
                        label: const Text('OUT'),
                        selected: selectedFilter == 'OUT',
                        onSelected: (_) {
                          setState(() {
                            selectedFilter = 'OUT';
                          });
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  if (shownTransactions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text('No transactions to show'),
                      ),
                    )
                  else
                    ...shownTransactions.map(
                          (transaction) {
                        final isMoneyIn =
                            transaction.type == TransactionType.moneyIn;

                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Icon(
                                isMoneyIn
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                              ),
                            ),
                            title: Text(transaction.description),
                            subtitle: Text(
                              isMoneyIn ? 'IN' : 'OUT',
                              style: TextStyle(
                                color: isMoneyIn
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${isMoneyIn ? '+' : '-'}${formatMoney(transaction.amount)}',
                                  style: TextStyle(
                                    color: isMoneyIn
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    deleteTransaction(transaction);
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// RECEIVE MONEY SCREEN
// ============================================================

class ReceiveMoneyScreen extends StatefulWidget {
  const ReceiveMoneyScreen({super.key});

  @override
  State<ReceiveMoneyScreen> createState() =>
      _ReceiveMoneyScreenState();
}

class _ReceiveMoneyScreenState
    extends State<ReceiveMoneyScreen> {
  final amountController = TextEditingController();
  final descriptionController = TextEditingController();

  void receiveMoney() {
    final amountText = amountController.text.trim();
    final description = descriptionController.text.trim();

    final amount = int.tryParse(amountText);

    if (amount == null) {
      showError('Amount must be a whole number.');
      return;
    }

    if (amount <= 0) {
      showError('Amount must be above 0 RWF.');
      return;
    }

    if (description.isEmpty) {
      showError('Description cannot be empty.');
      return;
    }

    final transaction = WalletTransaction(
      description: description,
      amount: amount,
      type: TransactionType.moneyIn,
      date: DateTime.now(),
    );

    Navigator.pop(context, transaction);
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  void dispose() {
    amountController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive Money'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Example: Received from David',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount',
              suffixText: 'RWF',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: receiveMoney,
            child: const Text('Receive Money'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SEND MONEY SCREEN
// ============================================================

class SendMoneyScreen extends StatefulWidget {
  const SendMoneyScreen({
    super.key,
    required this.availableBalance,
  });

  final int availableBalance;

  @override
  State<SendMoneyScreen> createState() =>
      _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  final phoneController = TextEditingController();
  final amountController = TextEditingController();

  void sendMoney() {
    final phone = phoneController.text.trim();
    final amountText = amountController.text.trim();

    if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
      showError('Phone number must contain exactly 10 digits.');
      return;
    }

    if (!phone.startsWith('078') && !phone.startsWith('079')) {
      showError('Phone number must start with 078 or 079.');
      return;
    }

    final amount = int.tryParse(amountText);

    if (amount == null) {
      showError('Amount must be a whole number.');
      return;
    }

    if (amount < 100) {
      showError('Minimum send amount is 100 RWF.');
      return;
    }

    if (amount > widget.availableBalance) {
      showError('Insufficient balance');
      return;
    }

    final transaction = WalletTransaction(
      description: 'Sent to $phone',
      amount: amount,
      type: TransactionType.moneyOut,
      date: DateTime.now(),
    );

    Navigator.pop(context, transaction);
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  void dispose() {
    phoneController.dispose();
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Money'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Available: ${widget.availableBalance} RWF',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              hintText: '0788123456',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount',
              suffixText: 'RWF',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: sendMoney,
            icon: const Icon(Icons.send),
            label: const Text('Send Money'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CASH OUT SCREEN
// ============================================================

class CashOutScreen extends StatefulWidget {
  const CashOutScreen({
    super.key,
    required this.availableBalance,
  });

  final int availableBalance;

  @override
  State<CashOutScreen> createState() =>
      _CashOutScreenState();
}

class _CashOutScreenState extends State<CashOutScreen> {
  final amountController = TextEditingController();

  Map<int, int> notes = {};

  int? get enteredAmount {
    return int.tryParse(amountController.text.trim());
  }

  Map<int, int> calculateNotes(int amount) {
    final denominations = [
      5000,
      2000,
      1000,
      500,
      100,
    ];

    int remaining = amount;

    final result = <int, int>{};

    for (final denomination in denominations) {
      final quantity = remaining ~/ denomination;

      if (quantity > 0) {
        result[denomination] = quantity;
        remaining %= denomination;
      }
    }

    return result;
  }

  void previewCashOut() {
    final amount = enteredAmount;

    if (amount == null) {
      showError('Amount must be a whole number.');
      return;
    }

    if (amount <= 0) {
      showError('Amount must be above 0 RWF.');
      return;
    }

    if (amount % 100 != 0) {
      showError('Cash out amount must be a multiple of 100 RWF.');
      return;
    }

    if (amount > widget.availableBalance) {
      showError('Insufficient balance');
      return;
    }

    setState(() {
      notes = calculateNotes(amount);
    });
  }

  void confirmCashOut() {
    final amount = enteredAmount;

    if (amount == null ||
        amount <= 0 ||
        amount % 100 != 0 ||
        amount > widget.availableBalance) {
      previewCashOut();
      return;
    }

    final transaction = WalletTransaction(
      description: 'Cash out',
      amount: amount,
      type: TransactionType.moneyOut,
      date: DateTime.now(),
    );

    Navigator.pop(context, transaction);
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Out'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Available balance: ${widget.availableBalance} RWF',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Cash out amount',
              suffixText: 'RWF',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),

          OutlinedButton(
            onPressed: previewCashOut,
            child: const Text('Show Notes'),
          ),

          const SizedBox(height: 24),

          if (notes.isNotEmpty) ...[
            const Text(
              'Agent will give you:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            ...notes.entries.map(
                  (entry) => Card(
                child: ListTile(
                  leading: const Icon(Icons.payments),
                  title: Text('${entry.key} RWF'),
                  trailing: Text(
                    '× ${entry.value}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            FilledButton(
              onPressed: confirmCashOut,
              child: const Text('Confirm Cash Out'),
            ),
          ],
        ],
      ),
    );
  }
}