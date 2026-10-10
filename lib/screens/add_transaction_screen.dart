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
  }) : titleController = TextEditingController(text: title),
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

enum _TransactionEntryMode { receipt, manual }

class AddTransactionScreen extends StatefulWidget {
  final Transaction? transaction;

  const AddTransactionScreen({super.key, this.transaction});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _EntryModeOption extends StatelessWidget {
  const _EntryModeOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(description, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  static final List<ExpenseCategory> _receiptCategoryOptions = ExpenseCategory
      .values
      .where((category) => category != ExpenseCategory.salary)
      .toList(growable: false);

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
  bool _showReceiptReview = false;
  _TransactionEntryMode? _entryMode;
  final List<_ReceiptItemDraft> _receiptItems = [];

  bool _isSaving = false;

  bool get _isEditing => widget.transaction != null;

  ExpenseCategory _receiptCategoryOrFallback(ExpenseCategory category) =>
      _receiptCategoryOptions.contains(category)
      ? category
      : ExpenseCategory.other;

  List<ExpenseCategory> get _manualCategoryOptions =>
      _selectedType == TransactionType.income
      ? const [ExpenseCategory.salary]
      : ExpenseCategory.values
            .where((category) => category != ExpenseCategory.salary)
            .toList(growable: false);

  ExpenseCategory _manualCategoryOrFallback(ExpenseCategory category) =>
      _manualCategoryOptions.contains(category)
      ? category
      : _selectedType == TransactionType.income
      ? ExpenseCategory.salary
      : ExpenseCategory.food;

  void _selectEntryMode(_TransactionEntryMode mode) {
    for (final item in _receiptItems) {
      item.dispose();
    }
    _receiptItems.clear();
    setState(() {
      _entryMode = mode;
      _showReceiptReview = false;
      _titleController.clear();
      _amountController.clear();
      _selectedType = TransactionType.expense;
      _selectedCategory = ExpenseCategory.food;
      _selectedCurrency = TransactionCurrency.unknown;
      _selectedDate = DateTime.now();
    });
  }

  void _returnToEntryModeChoice() {
    for (final item in _receiptItems) {
      item.dispose();
    }
    _receiptItems.clear();
    setState(() {
      _entryMode = null;
      _showReceiptReview = false;
      _titleController.clear();
      _amountController.clear();
      _selectedType = TransactionType.expense;
      _selectedCategory = ExpenseCategory.food;
      _selectedCurrency = TransactionCurrency.unknown;
      _selectedDate = DateTime.now();
    });
  }

  void _removeReceiptItem(int index) {
    final removedItem = _receiptItems[index];
    setState(() {
      _receiptItems.removeAt(index);
    });
    removedItem.dispose();
  }

  @override
  void initState() {
    super.initState();

    _receiptOcrService = ReceiptOcrService();
    _mlApiService = MlApiService();

    final transaction = widget.transaction;

    if (transaction != null) {
      _entryMode = _TransactionEntryMode.manual;
      _titleController.text = transaction.title;
      _amountController.text = transaction.amount.toString();
      _selectedType = transaction.type;
      _selectedCategory = _manualCategoryOrFallback(transaction.category);
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

          var category = _receiptCategoryOrFallback(item.category);

          try {
            final prediction = await _mlApiService
                .predictCategory(title)
                .timeout(const Duration(seconds: 3));

            if (prediction != null) {
              category = _receiptCategoryOrFallback(
                _categoryFromMlName(prediction.category) ?? category,
              );
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
        _showReceiptReview = true;

        if (result.amount != null) {
          _amountController.text = result.amount!.toStringAsFixed(2);
        }

        if (result.merchant != null && _titleController.text.trim().isEmpty) {
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      debugPrint('Receipt scan failed: $error');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not scan this receipt. Try a clearer image.'),
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
    if (_entryMode == null) return;

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
            amount: double.parse(_amountController.text.trim()),
            type: _selectedType,
            category: _manualCategoryOrFallback(_selectedCategory),
            date: _selectedDate,
            currency: _selectedCurrency,
          ),
        );

        if (!mounted) return;

        Navigator.of(context).pop();
        return;
      }

      if (_entryMode == _TransactionEntryMode.receipt && !_showReceiptReview) {
        return;
      }

      // RECEIPT: Save each product separately.
      if (_entryMode == _TransactionEntryMode.receipt &&
          _receiptItems.isNotEmpty) {
        if (_selectedType != TransactionType.expense) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Receipt items can only be saved as expenses.'),
            ),
          );
          return;
        }

        for (final item in _receiptItems) {
          final title = item.titleController.text.trim();

          final amount = double.parse(item.amountController.text.trim());

          await provider.addTransaction(
            title: title,
            amount: amount,
            type: TransactionType.expense,
            category: _receiptCategoryOrFallback(item.category),
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

      // Manual entry or a receipt without detected line items saves one
      // transaction using the visible title and amount fields.
      await provider.addTransaction(
        title: _titleController.text.trim(),
        amount: double.parse(_amountController.text.trim()),
        type: _selectedType,
        category: _entryMode == _TransactionEntryMode.manual
            ? _manualCategoryOrFallback(_selectedCategory)
            : _receiptCategoryOrFallback(_selectedCategory),
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
            content: Text('Could not save the transaction. Please try again.'),
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
                    color: theme.textTheme.bodyMedium?.color?.withValues(
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
                    : _entryMode == null
                    ? 'Add Transaction'
                    : _entryMode == _TransactionEntryMode.receipt
                    ? 'Scan Receipt'
                    : 'Enter Manually',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              if (!_isEditing && _entryMode == null) ...[
                _EntryModeOption(
                  icon: Icons.document_scanner_outlined,
                  title: 'Scan Receipt (OCR)',
                  description:
                      'Scan with your camera or choose a receipt image. '
                      'Review, edit, and remove detected items before saving.',
                  onTap: () => _selectEntryMode(_TransactionEntryMode.receipt),
                ),
                const SizedBox(height: 12),
                _EntryModeOption(
                  icon: Icons.edit_note_rounded,
                  title: 'Enter Manually',
                  description:
                      'Add one transaction by entering its description, '
                      'amount, and category.',
                  onTap: () => _selectEntryMode(_TransactionEntryMode.manual),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],

              if (_entryMode != null) ...[
                if (!_isEditing)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _isScanningReceipt
                          ? null
                          : _returnToEntryModeChoice,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Change entry method'),
                    ),
                  ),

                // 1. Transaction Type Toggle
                SegmentedButton<TransactionType>(
                  segments: const [
                    ButtonSegment<TransactionType>(
                      value: TransactionType.expense,
                      label: Text('Expense'),
                      icon: Icon(Icons.arrow_upward_rounded, size: 18),
                    ),
                    ButtonSegment<TransactionType>(
                      value: TransactionType.income,
                      label: Text('Income'),
                      icon: Icon(Icons.arrow_downward_rounded, size: 18),
                    ),
                  ],
                  selected: {_selectedType},
                  onSelectionChanged: (newSelection) {
                    setState(() {
                      _selectedType = newSelection.first;

                      if (_selectedType == TransactionType.expense &&
                          _selectedCategory == ExpenseCategory.salary) {
                        _selectedCategory = ExpenseCategory.food;
                      } else if (_selectedType == TransactionType.income) {
                        _selectedCategory = ExpenseCategory.salary;
                      }
                      _selectedCategory = _manualCategoryOrFallback(
                        _selectedCategory,
                      );
                    });
                  },
                ),

                if (_entryMode == _TransactionEntryMode.receipt) ...[
                  const SizedBox(height: 20),

                  // 2. Receipt OCR + ML
                  OutlinedButton.icon(
                    onPressed: _isScanningReceipt ? null : _scanReceipt,
                    icon: _isScanningReceipt
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.document_scanner_outlined),
                    label: Text(
                      _isScanningReceipt
                          ? 'Scanning receipt...'
                          : 'Scan receipt with OCR',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Scan a receipt to fill in the amount and merchant. '
                    'Detected items are classified where predictions are available.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withValues(
                        alpha: 0.65,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  // Receipt item review section.
                  if (_showReceiptReview) ...[
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

                    if (_receiptItems.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No receipt items left. You can save the receipt total '
                          'as one transaction or scan another receipt.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),

                    ...List.generate(_receiptItems.length, (index) {
                      final item = _receiptItems[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Item ${index + 1}',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Remove item ${index + 1}',
                                    onPressed: () => _removeReceiptItem(index),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                    ),
                                    color: theme.colorScheme.error,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
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
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: InputDecoration(
                                  labelText: 'Amount',
                                  prefixText: '${_selectedCurrency.symbol} ',
                                  border: const OutlineInputBorder(),
                                ),

                                validator: (value) {
                                  final amount = double.tryParse(
                                    value?.trim() ?? '',
                                  );

                                  if (amount == null || amount <= 0) {
                                    return 'Enter a valid amount';
                                  }

                                  return null;
                                },
                              ),

                              const SizedBox(height: 10),

                              DropdownButtonFormField<ExpenseCategory>(
                                initialValue: _receiptCategoryOrFallback(
                                  item.category,
                                ),
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                  border: OutlineInputBorder(),
                                ),
                                items: _receiptCategoryOptions
                                    .map(
                                      (category) =>
                                          DropdownMenuItem<ExpenseCategory>(
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
                ],
                if (_entryMode == _TransactionEntryMode.receipt) ...[
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
                      setState(() => _selectedCurrency = currency);
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                if (_entryMode == _TransactionEntryMode.manual ||
                    (_entryMode == _TransactionEntryMode.receipt &&
                        _showReceiptReview &&
                        _receiptItems.isEmpty)) ...[
                  if (_entryMode == _TransactionEntryMode.manual) ...[
                    TextFormField(
                      controller: _titleController,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Item Name / Description',
                        hintText: 'e.g. Groceries',
                        border: OutlineInputBorder(),
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
                    const SizedBox(height: 16),
                    DropdownButtonFormField<ExpenseCategory>(
                      initialValue: _manualCategoryOrFallback(
                        _selectedCategory,
                      ),
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      validator: (category) =>
                          category == null ? 'Choose a category' : null,
                      items: _manualCategoryOptions
                          .map(
                            (category) => DropdownMenuItem<ExpenseCategory>(
                              value: category,
                              child: Text(category.displayName),
                            ),
                          )
                          .toList(),
                      onChanged: (category) {
                        if (category == null) return;
                        setState(() => _selectedCategory = category);
                      },
                    ),
                    const SizedBox(height: 16),
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
                        setState(() => _selectedCurrency = currency);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  // 3. Amount Input Field
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
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
                      prefixStyle: const TextStyle(fontSize: 16),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter an amount';
                      }

                      final amount = double.tryParse(value.trim());

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

                  if (_entryMode == _TransactionEntryMode.receipt) ...[
                    TextFormField(
                      controller: _titleController,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Title / Description',
                        hintText: 'e.g. Weekly Grocery shopping',
                        border: OutlineInputBorder(),
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
                  ],
                ],

                if (_entryMode == _TransactionEntryMode.manual ||
                    (_entryMode == _TransactionEntryMode.receipt &&
                        _showReceiptReview)) ...[
                  // 5. Date Selector
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
                          color: theme.dividerColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          Text(
                            DateFormat('MMM dd, yyyy').format(_selectedDate),
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

                  // 6. Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
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
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            elevation: 0,
                          ),
                          child: Text(
                            _isSaving
                                ? 'Saving...'
                                : (_entryMode ==
                                              _TransactionEntryMode.receipt &&
                                          _receiptItems.isNotEmpty
                                      ? 'Save ${_receiptItems.length} Items'
                                      : (_isEditing ? 'Update' : 'Save')),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
