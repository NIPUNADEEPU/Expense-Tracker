import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import '../providers/expense_provider.dart';
import '../services/receipt_ocr_service.dart';

enum _Stage { choose, manual, review }

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key, this.transaction});
  final Transaction? transaction;
  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _picker = ImagePicker();
  late final ReceiptOcrService _ocr;
  final List<ReceiptLineItem> _items = [];
  Uint8List? _receiptPreviewBytes;
  TransactionType _type = TransactionType.expense;
  ExpenseCategory _category = ExpenseCategory.food;
  DateTime _date = DateTime.now();
  _Stage _stage = _Stage.choose;
  bool _scanning = false, _saving = false;
  bool _receiptDateConfirmed = false;
  bool get _editing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    _ocr = ReceiptOcrService();
    final t = widget.transaction;
    if (t != null) {
      _stage = _Stage.manual;
      _title.text = t.title;
      _amount.text = t.amount.toString();
      _type = t.type;
      _category = t.category;
      _date = t.date;
    }
  }

  @override
  void dispose() {
    _ocr.dispose();
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
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
    if (source == null) return;
    try {
      final image = await _picker.pickImage(source: source, imageQuality: 90);
      if (image == null) return;
      final previewBytes = await image.readAsBytes();
      setState(() => _scanning = true);
      final result = await _ocr.scanImage(image.path);
      if (!mounted) return;
      setState(() {
        _receiptPreviewBytes = previewBytes;
        _items
          ..clear()
          ..addAll(result.items);
        _date = DateTime.now();
        _receiptDateConfirmed = false;
        if (result.items.isEmpty) _category = ExpenseCategory.other;
        if (result.items.isEmpty && result.amount != null) {
          _amount.text = result.amount!.toStringAsFixed(2);
        }
        if (result.merchant != null) _title.text = result.merchant!;
        _stage = _Stage.review;
      });
      if (result.items.isEmpty && result.amount == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No receipt total found. Enter the amount manually.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not scan this receipt. Try a clearer image.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _chooseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        if (_stage == _Stage.review) _receiptDateConfirmed = true;
      });
    }
  }

  Future<void> _save() async {
    if (_stage == _Stage.review && _items.isNotEmpty) {
      if (!_receiptDateConfirmed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Choose the receipt purchase date before saving.'),
          ),
        );
        return;
      }
      setState(() => _saving = true);
      try {
        await ExpenseScope.of(context).addTransactions(
          items: _items
              .map(
                (i) => (title: i.title, amount: i.amount, category: i.category),
              )
              .toList(),
          date: _date,
        );
        if (mounted) Navigator.pop(context);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not save receipt items. Try again.'),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      return;
    }
    if (_stage == _Stage.review) {
      if (!_receiptDateConfirmed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Choose the receipt purchase date before saving.'),
          ),
        );
        return;
      }
      final amount = double.tryParse(_amount.text.trim());
      if (amount == null || amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid receipt total to save.')),
        );
        return;
      }
      setState(() => _saving = true);
      try {
        await ExpenseScope.of(context).addTransaction(
          title: _title.text.trim().isEmpty ? 'Receipt' : _title.text.trim(),
          amount: amount,
          type: TransactionType.expense,
          category: _category,
          date: _date,
        );
        if (mounted) Navigator.pop(context);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not save the transaction. Try again.'),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final provider = ExpenseScope.of(context);
    final existing = widget.transaction;
    final title = _title.text.trim();
    final amount = double.parse(_amount.text.trim());
    if (existing == null) {
      await provider.addTransaction(
        title: title,
        amount: amount,
        type: _type,
        category: _category,
        date: _date,
      );
    } else {
      provider.updateTransaction(
        Transaction(
          id: existing.id,
          title: title,
          amount: amount,
          type: _type,
          category: _category,
          date: _date,
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .92,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 17, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _stage == _Stage.choose
                          ? 'Add transaction'
                          : _stage == _Stage.review
                          ? 'Review receipt'
                          : _editing
                          ? 'Edit transaction'
                          : 'New transaction',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_stage != _Stage.choose && !_editing)
                    TextButton(
                      onPressed: () => setState(() => _stage = _Stage.choose),
                      child: const Text('Back'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: _stage == _Stage.choose
                    ? _choice(theme)
                    : _stage == _Stage.review
                    ? _review(theme, currency)
                    : _manual(theme),
              ),
            ),
            if (_stage != _Stage.choose)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _scanning || _saving ? null : _save,
                    child: Text(
                      _saving
                          ? 'Saving…'
                          : _stage == _Stage.review && _items.isNotEmpty
                          ? 'Confirm & save ${_items.length} items'
                          : _editing
                          ? 'Update transaction'
                          : 'Save transaction',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _choice(ThemeData theme) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('How would you like to add it?', style: theme.textTheme.bodyMedium),
      const SizedBox(height: 20),
      _ChoiceTile(
        icon: Icons.document_scanner_outlined,
        title: 'Scan receipt',
        subtitle: 'Automatically extract transaction details',
        onTap: _scanning ? null : _startScan,
        trailing: _scanning
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
      ),
      const SizedBox(height: 12),
      _ChoiceTile(
        icon: Icons.edit_note_rounded,
        title: 'Enter manually',
        subtitle: 'Add a transaction yourself',
        onTap: () => setState(() => _stage = _Stage.manual),
      ),
      const SizedBox(height: 12),
      Text(
        'Receipt details are checked before saving.',
        style: theme.textTheme.bodySmall,
      ),
    ],
  );

  Widget _manual(ThemeData theme) => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<TransactionType>(
          segments: const [
            ButtonSegment(
              value: TransactionType.expense,
              label: Text('Expense'),
            ),
            ButtonSegment(value: TransactionType.income, label: Text('Income')),
          ],
          selected: {_type},
          onSelectionChanged: (v) => setState(() {
            _type = v.first;
            _category = v.first == TransactionType.income
                ? ExpenseCategory.salary
                : (_category == ExpenseCategory.salary
                      ? ExpenseCategory.food
                      : _category);
          }),
        ),
        const SizedBox(height: 22),
        TextFormField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          decoration: const InputDecoration(
            labelText: 'Amount',
            prefixText: '₹ ',
            hintText: '0.00',
          ),
          validator: (v) {
            final a = double.tryParse((v ?? '').trim());
            if (a == null || a <= 0) return 'Enter an amount greater than zero';
            return null;
          },
        ),
        const SizedBox(height: 18),
        TextFormField(
          controller: _title,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Description',
            hintText: 'What was this for?',
          ),
          validator: (v) => v == null || v.trim().length < 3
              ? 'Enter a description (at least 3 characters)'
              : null,
        ),
        const SizedBox(height: 22),
        Text(
          'Category',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ExpenseCategory.values
              .where(
                (c) => _type == TransactionType.income
                    ? c == ExpenseCategory.salary || c == ExpenseCategory.other
                    : c != ExpenseCategory.salary &&
                          c != ExpenseCategory.uncategorized,
              )
              .map(
                (c) => ChoiceChip(
                  avatar: Icon(
                    c.icon,
                    size: 17,
                    color: _category == c ? Colors.white : c.color,
                  ),
                  label: Text(c.displayName),
                  selected: _category == c,
                  onSelected: (_) => setState(() => _category = c),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 20),
        _DateRow(date: _date, onTap: _chooseDate),
      ],
    ),
  );

  Widget _review(ThemeData theme, NumberFormat currency) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_receiptPreviewBytes != null) ...[
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(
            _receiptPreviewBytes!,
            height: 180,
            width: double.infinity,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 16),
      ],
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.storefront_outlined, color: Color(0xFF8B5CF6)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title.text.isEmpty ? 'Receipt merchant' : _title.text,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  Text(
                    _receiptDateConfirmed
                        ? DateFormat('d MMM yyyy').format(_date)
                        : 'Purchase date not detected',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _chooseDate,
              child: Text(_receiptDateConfirmed ? 'Change date' : 'Set date'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Text(
        'Detected items',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 7),
      if (_items.isEmpty)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('No separate items were detected.'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Receipt total',
                  prefixText: '₹ ',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Merchant / description',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ExpenseCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: ExpenseCategory.values
                    .where(
                      (category) =>
                          category != ExpenseCategory.salary &&
                          category != ExpenseCategory.uncategorized,
                    )
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (category) {
                  if (category != null) setState(() => _category = category);
                },
              ),
            ],
          ),
        )
      else
        ..._items.asMap().entries.map((e) {
          final i = e.key, item = e.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        currency.format(item.amount),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                DropdownButton<ExpenseCategory>(
                  value: item.category,
                  underline: const SizedBox(),
                  onChanged: (c) {
                    if (c != null) {
                      setState(() => _items[i] = item.copyWith(category: c));
                    }
                  },
                  items: ExpenseCategory.values
                      .where(
                        (c) =>
                            c != ExpenseCategory.salary &&
                            c != ExpenseCategory.uncategorized,
                      )
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.displayName),
                        ),
                      )
                      .toList(),
                ),
                IconButton(
                  onPressed: () => setState(() => _items.removeAt(i)),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Remove item',
                ),
              ],
            ),
          );
        }),
      const Divider(height: 26),
      Row(
        children: [
          const Expanded(
            child: Text(
              'Total',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          Text(
            currency.format(
              _items.isNotEmpty
                  ? _items.fold<double>(0, (sum, i) => sum + i.amount)
                  : double.tryParse(_amount.text) ?? 0,
            ),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        'Review the detected details and categories before saving.',
        style: theme.textTheme.bodySmall,
      ),
    ],
  );
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.date, required this.onTap});
  final DateTime date;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Date',
        suffixIcon: Icon(Icons.calendar_today_outlined),
      ),
      child: Text(DateFormat('EEE, d MMM yyyy').format(date)),
    ),
  );
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).cardColor,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            trailing ?? const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}
