import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MomoWalletApp());
}

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
      home: const AuthGate(),
    );
  }
}

// ============================================================
// AUTH GATE
// ============================================================

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const WalletScreen();
        }

        return const LoginScreen();
      },
    );
  }
}

// ============================================================
// LOGIN / SIGN UP
// ============================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLogin = true;
  bool loading = false;

  Future<void> submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showMessage('Enter email and password.');
      return;
    }

    if (password.length < 6) {
      showMessage('Password must contain at least 6 characters.');
      return;
    }

    setState(() => loading = true);

    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } on FirebaseAuthException catch (e) {
      showMessage(e.message ?? 'Authentication failed.');
    } catch (_) {
      showMessage('Something went wrong.');
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.yellow.shade600,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet,
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'MoMo Wallet',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isLogin
                        ? 'Sign in to your wallet'
                        : 'Create your wallet account',
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: loading ? null : submit,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: loading
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(),
                        )
                            : Text(isLogin ? 'Login' : 'Create Account'),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: loading
                        ? null
                        : () {
                      setState(() => isLogin = !isLogin);
                    },
                    child: Text(
                      isLogin
                          ? 'No account? Sign up'
                          : 'Already have an account? Login',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MODEL
// ============================================================

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.description,
    required this.amount,
    required this.isIn,
    required this.createdAt,
  });

  final String id;
  final String description;
  final int amount;
  final bool isIn;
  final DateTime createdAt;

  factory WalletTransaction.fromDocument(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data()!;

    final timestamp = data['createdAt'];

    return WalletTransaction(
      id: document.id,
      description: data['description'] ?? '',
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      isIn: data['isIn'] ?? false,
      createdAt:
      timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
    );
  }
}

// ============================================================
// FIRESTORE SERVICE
// ============================================================

class TransactionService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get transactions {
    return firestore
        .collection('users')
        .doc(uid)
        .collection('transactions');
  }

  Stream<List<WalletTransaction>> watchTransactions() {
    return transactions
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map(WalletTransaction.fromDocument)
          .toList(),
    );
  }

  Future<void> addTransaction({
    required String description,
    required int amount,
    required bool isIn,
  }) async {
    await transactions.add({
      'description': description,
      'amount': amount,
      'isIn': isIn,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateTransaction({
    required String id,
    required String description,
    required int amount,
  }) async {
    await transactions.doc(id).update({
      'description': description,
      'amount': amount,
    });
  }

  Future<void> deleteTransaction(String id) async {
    await transactions.doc(id).delete();
  }
}

// ============================================================
// WALLET
// ============================================================

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  static const int startingBalance = 10000;

  final TransactionService service = TransactionService();

  String filter = 'All';

  int calculateBalance(List<WalletTransaction> transactions) {
    int balance = startingBalance;

    for (final transaction in transactions) {
      if (transaction.isIn) {
        balance += transaction.amount;
      } else {
        balance -= transaction.amount;
      }
    }

    return balance;
  }

  int calculateTotalIn(List<WalletTransaction> transactions) {
    return transactions
        .where((transaction) => transaction.isIn)
        .fold(0, (total, transaction) => total + transaction.amount);
  }

  int calculateTotalOut(List<WalletTransaction> transactions) {
    return transactions
        .where((transaction) => !transaction.isIn)
        .fold(0, (total, transaction) => total + transaction.amount);
  }

  int calculateLowestBalance(List<WalletTransaction> transactions) {
    int balance = startingBalance;
    int lowest = startingBalance;

    for (final transaction in transactions) {
      if (transaction.isIn) {
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

  List<WalletTransaction> applyFilter(
      List<WalletTransaction> transactions,
      ) {
    Iterable<WalletTransaction> result = transactions.reversed;

    if (filter == 'IN') {
      result = result.where((transaction) => transaction.isIn);
    }

    if (filter == 'OUT') {
      result = result.where((transaction) => !transaction.isIn);
    }

    return result.toList();
  }

  String money(int amount) {
    final text = amount.toString();
    final result = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) {
        result.write(',');
      }
      result.write(text[i]);
    }

    return '${result.toString()} RWF';
  }

  Future<void> showTransactionForm({
    required bool isIn,
    WalletTransaction? existing,
  }) async {
    final descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );

    final amountController = TextEditingController(
      text: existing?.amount.toString() ?? '',
    );

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            existing != null
                ? 'Edit Transaction'
                : isIn
                ? 'Receive Money'
                : 'Send Money',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (RWF)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final description =
                descriptionController.text.trim();

                final amount = int.tryParse(
                  amountController.text.trim(),
                );

                if (description.isEmpty ||
                    amount == null ||
                    amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Enter a description and a valid whole amount.',
                      ),
                    ),
                  );
                  return;
                }

                if (existing == null) {
                  await service.addTransaction(
                    description: description,
                    amount: amount,
                    isIn: isIn,
                  );
                } else {
                  await service.updateTransaction(
                    id: existing.id,
                    description: description,
                    amount: amount,
                  );
                }

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: Text(existing == null ? 'Save' : 'Update'),
            ),
          ],
        );
      },
    );

    descriptionController.dispose();
    amountController.dispose();
  }

  Future<void> deleteTransaction(
      WalletTransaction transaction,
      ) async {
    await service.deleteTransaction(transaction.id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Transaction deleted'),
      ),
    );
  }

  Widget statistic(String title, int value) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 6,
          ),
          child: Column(
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 5),
              Text(
                money(value),
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MoMo Wallet',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<List<WalletTransaction>>(
        stream: service.watchTransactions(),
        builder: (context, snapshot) {
          // LOADING STATE
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // ERROR STATE
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load transactions.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // DATA STATE
          final transactions = snapshot.data ?? [];

          final balance = calculateBalance(transactions);
          final totalIn = calculateTotalIn(transactions);
          final totalOut = calculateTotalOut(transactions);
          final lowest = calculateLowestBalance(transactions);

          final displayed = applyFilter(transactions);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                user.email ?? 'Signed in',
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
              ),

              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade600,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Available Balance'),
                    const SizedBox(height: 8),
                    Text(
                      money(balance),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        showTransactionForm(isIn: true);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Receive'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        showTransactionForm(isIn: false);
                      },
                      icon: const Icon(Icons.send),
                      label: const Text('Send'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

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
                  statistic('Total IN', totalIn),
                  statistic('Total OUT', totalOut),
                  statistic('Lowest', lowest),
                ],
              ),

              const SizedBox(height: 22),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Transactions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('${transactions.length} total'),
                ],
              ),

              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                children: [
                  for (final option in ['All', 'IN', 'OUT'])
                    ChoiceChip(
                      label: Text(option),
                      selected: filter == option,
                      onSelected: (_) {
                        setState(() => filter = option);
                      },
                    ),
                ],
              ),

              const SizedBox(height: 10),

              if (displayed.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 50),
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 55,
                      ),
                      SizedBox(height: 10),
                      Text('No transactions yet'),
                    ],
                  ),
                )
              else
                ...displayed.map(
                      (transaction) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          transaction.isIn
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                        ),
                      ),
                      title: Text(transaction.description),
                      subtitle: Text(
                        transaction.isIn ? 'IN' : 'OUT',
                        style: TextStyle(
                          color: transaction.isIn
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${transaction.isIn ? '+' : '-'}${money(transaction.amount)}',
                            style: TextStyle(
                              color: transaction.isIn
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                showTransactionForm(
                                  isIn: transaction.isIn,
                                  existing: transaction,
                                );
                              }

                              if (value == 'delete') {
                                deleteTransaction(transaction);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}