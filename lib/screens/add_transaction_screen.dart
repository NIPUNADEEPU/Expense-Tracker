import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';


import '../models/category.dart';
import '../models/transaction.dart';
import '../providers/expense_provider.dart';
import '../services/ml_api_service.dart';
import '../services/receipt_ocr_service.dart';

class _ReceiptItemDraft {
  _ReceiptItemDraft({
    required String title,
    required double amount,
    required this.category,
  })  : titleController = TextEditingController(text: title),
        amountController = TextEditingController(
          text: amount.toStringAsFixed(2),
        );

  final TextEditingController titleController;
  final TextEditingController amountController;
  ExpenseCategory category;

  void dispose() {
    titleController.dispose();
    amountController.dispose();
  }
}
class AddTransactionScreen extends StatefulWidget {
  final Transaction? transaction;

  const AddTransactionScreen({super.key, this.transaction});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _imagePicker = ImagePicker();

  late final ReceiptOcrService _receiptOcrService;
  late final MlApiService _mlApiService;

  TransactionType _selectedType = TransactionType.expense;
  ExpenseCategory _selectedCategory = ExpenseCategory.food;
  DateTime _selectedDate = DateTime.now();
  TransactionCurrency _selectedCurrency = TransactionCurrency.unknown;
  bool _isScanningReceipt = false;
  final List<_ReceiptItemDraft> _receiptItems = [];

bool _isSaving = false;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();

    _receiptOcrService = ReceiptOcrService();
    _mlApiService = MlApiService();

    final transaction = widget.transaction;

    if (transaction != null) {
      _titleController.text = transaction.title;
      _amountController.text = transaction.amount.toString();
      _selectedType = transaction.type;
      _selectedCategory = transaction.category;
      _selectedDate = transaction.date;
      _selectedCurrency = transaction.currency;
    }
  }

  @override
  void dispose() {
    _receiptOcrService.dispose();
    _titleController.dispose();
    _amountController.dispose();
    for (final item in _receiptItems) {
  item.dispose();
}
    super.dispose();
  }

  ExpenseCategory? _categoryFromMlName(String category) {
    switch (category.trim().toLowerCase()) {
      case 'food':
        return ExpenseCategory.food;

      case 'travel':
        return ExpenseCategory.travel;

      case 'shopping':
        return ExpenseCategory.shopping;

      case 'bills':
        return ExpenseCategory.bills;

      case 'entertainment':
        return ExpenseCategory.entertainment;

      case 'home':
        return ExpenseCategory.home;

      case 'personal care':
        return ExpenseCategory.personalCare;

      case 'financial':
        return ExpenseCategory.financial;

      default:
        return null;
    }
  }

 Future<void> _scanReceipt() async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (source == null || !mounted) return;

  try {
    final image = await _imagePicker.pickImage(
      source: source,
      imageQuality: 90,
    );

    if (image == null || !mounted) return;

    setState(() {
      _isScanningReceipt = true;
    });

    // STEP 1: Extract receipt information.
    final result = await _receiptOcrService.scanImage(image.path);

if (!mounted) return;

setState(() {
  _selectedCurrency = result.currency;
});

    // STEP 2: Classify each product separately without blocking the
    // whole receipt scan on slow ML responses.
    final drafts = <_ReceiptItemDraft>[];

    final classifiedItems = await Future.wait(
      result.items.map((item) async {
        final title = item.title.trim();

        if (title.isEmpty || item.totalPrice <= 0) {
          return null;
        }

        var category = item.category;

        try {
          final prediction = await _mlApiService
              .predictCategory(title)
              .timeout(const Duration(seconds: 3));

          if (prediction != null) {
            category = _categoryFromMlName(prediction.category) ?? category;
          }
        } catch (error) {
          debugPrint('ML classification failed for "$title": $error');
        }

        return _ReceiptItemDraft(
          title: title,
          amount: item.totalPrice,
          category: category,
        );
      }),
      eagerError: false,
    );

    for (final draft in classifiedItems.whereType<_ReceiptItemDraft>()) {
      drafts.add(draft);
    }

    if (!mounted) {
      for (final draft in drafts) {
        draft.dispose();
      }
      return;
    }

    // STEP 3: Store the detected products for review.
    setState(() {
      for (final item in _receiptItems) {
        item.dispose();
      }

      _receiptItems
        ..clear()
        ..addAll(drafts);

      if (result.amount != null) {
        _amountController.text = result.amount!.toStringAsFixed(2);
      }

      if (result.merchant != null &&
          _titleController.text.trim().isEmpty) {
        _titleController.text = result.merchant!;
      }

      // Use the first item's category for the existing
      // single-transaction form if no itemized list is saved.
      if (drafts.length == 1) {
        _selectedCategory = drafts.first.category;
      }
    });

    // STEP 4: Inform the user about the result.
    final message = drafts.isEmpty
        ? 'Receipt scanned, but no valid individual items were detected.'
        : '${drafts.length} receipt item(s) detected and classified. '
            'Review them before saving.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  } catch (error) {
    debugPrint('Receipt scan failed: $error');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not scan this receipt. Try a clearer image.',
          ),
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isScanningReceipt = false;
      });
    }
  }
}

  void _presentDatePicker() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  
    Future<void> _submitData() async {
    if (_isSaving) return;

    // Validate all visible form fields, including receipt items.
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = ExpenseScope.of(context);
    final existingTransaction = widget.transaction;

    setState(() {
      _isSaving = true;
    });

    try {
      // EDITING: Update the existing transaction.
      if (existingTransaction != null) {
        provider.updateTransaction(
          Transaction(
            id: existingTransaction.id,
            title: _titleController.text.trim(),
            amount: double.parse(
              _amountController.text.trim(),
            ),
            type: _selectedType,
            category: _selectedCategory,
            date: _selectedDate,
            currency: _selectedCurrency,
          ),
        );

        if (!mounted) return;

        Navigator.of(context).pop();
        return;
      }

      // RECEIPT: Save each product separately.
      if (_receiptItems.isNotEmpty) {
        if (_selectedType != TransactionType.expense) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Receipt items can only be saved as expenses.',
              ),
            ),
          );
          return;
        }

        for (final item in _receiptItems) {
          final title = item.titleController.text.trim();

          final amount = double.parse(
            item.amountController.text.trim(),
          );

          await provider.addTransaction(
            title: title,
            amount: amount,
            type: TransactionType.expense,
            category: item.category,
            date: _selectedDate,
            currency: _selectedCurrency,
          );
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_receiptItems.length} receipt items saved successfully.',
            ),
          ),
        );

        Navigator.of(context).pop();
        return;
      }

      // MANUAL ENTRY: Save one transaction.
      await provider.addTransaction(
        title: _titleController.text.trim(),
        amount: double.parse(
          _amountController.text.trim(),
        ),
        type: _selectedType,
        category: _selectedCategory,
        date: _selectedDate,
        currency: _selectedCurrency,
      );

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (error) {
      debugPrint('Transaction save failed: $error');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save the transaction. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pull Bar indicator
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color:
                        theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.15,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              Text(
                _isEditing
                    ? 'Edit Transaction'
                    : 'New Transaction',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              // 1. Transaction Type Toggle
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment<TransactionType>(
                    value: TransactionType.expense,
                    label: Text('Expense'),
                    icon: Icon(
                      Icons.arrow_upward_rounded,
                      size: 18,
                    ),
                  ),
                  ButtonSegment<TransactionType>(
                    value: TransactionType.income,
                    label: Text('Income'),
                    icon: Icon(
                      Icons.arrow_downward_rounded,
                      size: 18,
                    ),
                  ),
                ],
                selected: {_selectedType},
                onSelectionChanged: (newSelection) {
                  setState(() {
                    _selectedType = newSelection.first;

                    if (_selectedType == TransactionType.expense &&
                        _selectedCategory == ExpenseCategory.salary) {
                      _selectedCategory = ExpenseCategory.food;
                    } else if (_selectedType ==
                        TransactionType.income) {
                      _selectedCategory = ExpenseCategory.salary;
                    }
                  });
                },
              ),

              const SizedBox(height: 20),

              // 2. Receipt OCR + ML
              OutlinedButton.icon(
                onPressed:
                    _isScanningReceipt ? null : _scanReceipt,
                icon: _isScanningReceipt
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.document_scanner_outlined,
                      ),
                label: Text(
                  _isScanningReceipt
                      ? 'Scanning receipt...'
                      : 'Scan receipt with OCR',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Scan a receipt to fill in the amount and merchant. '
                'The ML model will classify a single detected item.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.65,
                  ),
                ),
              ),

              const SizedBox(height: 20),
              // Receipt item review section.
if (_receiptItems.isNotEmpty) ...[
  const SizedBox(height: 20),

  Text(
    'Receipt Items (${_receiptItems.length})',
    style: theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.bold,
    ),
  ),

  const SizedBox(height: 8),

  Text(
    'Review each product, amount, and predicted category.',
    style: theme.textTheme.bodySmall,
  ),

  const SizedBox(height: 12),

  ...List.generate(_receiptItems.length, (index) {
    final item = _receiptItems[index];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Item ${index + 1}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            TextFormField(
              controller: item.titleController,
              decoration: const InputDecoration(
                labelText: 'Product name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter a product name';
                }
                return null;
              },
            ),

            const SizedBox(height: 10),

            TextFormField(
              controller: item.amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
  labelText: 'Amount',
  prefixText: '${_selectedCurrency.symbol} ',
  border: const OutlineInputBorder(),
),

              validator: (value) {
                final amount = double.tryParse(value?.trim() ?? '');

                if (amount == null || amount <= 0) {
                  return 'Enter a valid amount';
                }

                return null;
              },
            ),

            const SizedBox(height: 10),

            DropdownButtonFormField<ExpenseCategory>(
              initialValue: item.category,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: ExpenseCategory.values
                  .where(
                    (category) =>
                        category != ExpenseCategory.salary &&
                        category != ExpenseCategory.other,
                  )
                  .map(
                    (category) => DropdownMenuItem<ExpenseCategory>(
                      value: category,
                      child: Text(category.displayName),
                    ),
                  )
                  .toList(),
              onChanged: (category) {
                if (category == null) return;

                setState(() {
                  item.category = category;
                });
              },
            ),
          ],
        ),
      ),
    );
  }),

  const Divider(height: 24),
],
// Currency selection
DropdownButtonFormField<TransactionCurrency>(
  initialValue: _selectedCurrency,
  decoration: const InputDecoration(
    labelText: 'Currency',
    border: OutlineInputBorder(),
  ),
  items: TransactionCurrency.values
      .map(
        (currency) => DropdownMenuItem<TransactionCurrency>(
          value: currency,
          child: Text(currency.displayName),
        ),
      )
      .toList(),
  onChanged: (currency) {
    if (currency == null) return;

    setState(() {
      _selectedCurrency = currency;
    });
  },
),
const SizedBox(height: 16),

              // 3. Amount Input Field
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
  labelText: 'Amount',
  prefixText: '${_selectedCurrency.symbol} ',
  prefixStyle: const TextStyle(
    fontSize: 16,
  ),
  border: const OutlineInputBorder(),
),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an amount';
                  }

                  final amount =
                      double.tryParse(value.trim());

                  if (amount == null) {
                    return 'Please enter a valid number';
                  }

                  if (amount <= 0) {
                    return 'Amount must be greater than zero';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              // 4. Title Input Field
              TextFormField(
                controller: _titleController,
                textCapitalization:
                    TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Title / Description',
                  hintText: 'e.g. Weekly Grocery shopping',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }

                  if (value.trim().length < 3) {
                    return 'Title should be at least 3 characters long';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 20),

              // 5. Category Selector
              Text(
                'Category',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color:
                      theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.8,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ExpenseCategory.values
                    .where((category) {
                  // Income: only Salary.
                  if (_selectedType ==
                      TransactionType.income) {
                    return category ==
                        ExpenseCategory.salary;
                  }

                  // Expense: only ML categories.
                  return category != ExpenseCategory.salary &&
                      category != ExpenseCategory.other;
                }).map((category) {
                  final isSelected =
                      _selectedCategory == category;

                  return ChoiceChip(
                    avatar: Icon(
                      category.icon,
                      color: isSelected
                          ? Colors.white
                          : category.color,
                      size: 16,
                    ),
                    label: Text(category.displayName),
                    selected: isSelected,
                    selectedColor: category.color,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedCategory = category;
                        });
                      }
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // 6. Date Selector
              InkWell(
                onTap: _presentDatePicker,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          theme.dividerColor.withValues(
                        alpha: 0.3,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Transaction Date',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        DateFormat('MMM dd, yyyy')
                            .format(_selectedDate),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // 7. Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _submitData,
                      style: ElevatedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                        ),
                        backgroundColor:
                            theme.colorScheme.primary,
                        foregroundColor:
                            theme.colorScheme.onPrimary,
                        elevation: 0,
                      ),
                      child: Text(
  _isSaving
      ? 'Saving...'
      : (_receiptItems.isNotEmpty
          ? 'Save ${_receiptItems.length} Items'
          : (_isEditing ? 'Update' : 'Save')),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}