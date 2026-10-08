import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Prompts the user with a confirmation dialog before discarding unsaved changes.
/// Returns `true` if the user confirms discarding changes, or `false` otherwise.
Future<bool> confirmDiscardUnsavedChanges(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber),
          SizedBox(width: 10),
          Text('Unsaved Changes'),
        ],
      ),
      content: const Text(
        'You have unsaved changes. Are you sure you want to discard your modifications and leave?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Keep Editing'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Discard Changes'),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// A structured section container for complex forms.
class AppFormSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AppFormSection({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.6,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 20, color: colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// Standardized text input field with contextual validation
class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final bool required;
  final bool enabled;
  final bool obscureText;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final int maxLines;
  final Widget? suffixIcon;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.required = false,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        border: const OutlineInputBorder(),
        prefixIcon: icon != null ? Icon(icon) : null,
        suffixIcon: suffixIcon,
      ),
      validator: (value) {
        final trimmed = value?.trim() ?? '';
        if (required && trimmed.isEmpty) {
          return '$label is required.';
        }
        if (validator != null) {
          return validator!(value);
        }
        return null;
      },
    );
  }
}

/// Cleanses and standardizes Philippine mobile numbers to 11-digit 09XXXXXXXXX format
String normalizePhilippinePhone(String? input) {
  if (input == null) return '';
  final digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('639') && digits.length == 12) {
    return '0${digits.substring(2)}';
  }
  if (digits.startsWith('9') && digits.length == 10) {
    return '0$digits';
  }
  return digits;
}

/// Checks if an input is a valid 11-digit Philippine mobile number
bool isValidPhilippinePhone(String? input) {
  if (input == null || input.trim().isEmpty) return false;
  final digits = normalizePhilippinePhone(input);
  return digits.length == 11 && digits.startsWith('09');
}

bool isValidEmailAddress(String? input) {
  final value = input?.trim() ?? '';
  return RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$",
  ).hasMatch(value);
}

bool isValidPostalAddress(String? input) {
  final value = input?.trim() ?? '';
  return value.length >= 3 &&
      value.length <= 200 &&
      RegExp(r'[A-Za-z0-9À-ÖØ-öø-ÿ]').hasMatch(value);
}

bool isValidPersonName(String? input) {
  final value = input?.trim() ?? '';
  return value.length >= 2 &&
      value.length <= 50 &&
      RegExp(r"^[A-Za-zÀ-ÖØ-öø-ÿ][A-Za-zÀ-ÖØ-öø-ÿ' -]*$")
          .hasMatch(value);
}

/// Formats a Philippine mobile number into standard 09XX-XXX-XXXX presentation
String formatPhilippinePhone(String? input) {
  final digits = normalizePhilippinePhone(input);
  if (digits.length != 11) return input?.trim() ?? '';
  return '${digits.substring(0, 4)}-${digits.substring(4, 7)}-${digits.substring(7)}';
}

/// Standardized Philippine phone field with 09XX-XXX-XXXX formatting
class AppPhoneField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool required;
  final bool enabled;
  final void Function(String)? onChanged;

  const AppPhoneField({
    super.key,
    required this.controller,
    this.label = 'Mobile Number',
    this.required = false,
    this.enabled = true,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d\s\-\+]')),
      ],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: '0917-123-4567',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.phone_outlined),
        helperText: 'Philippine 11-digit mobile (e.g. 0917-123-4567)',
      ),
      validator: (value) {
        final trimmed = value?.trim() ?? '';
        if (required && trimmed.isEmpty) {
          return '$label is required.';
        }
        if (trimmed.isNotEmpty) {
          if (!isValidPhilippinePhone(trimmed)) {
            return 'Enter a valid 11-digit mobile starting with 09.';
          }
        }
        return null;
      },
    );
  }
}

/// Date picker field with age auto-calculation and future-date restriction
class AppDatePickerField extends StatelessWidget {
  final String label;
  final DateTime? selectedDate;
  final ValueChanged<DateTime?> onDateSelected;
  final bool required;
  final bool preventFuture;
  final bool showAgeBadge;

  const AppDatePickerField({
    super.key,
    required this.label,
    required this.selectedDate,
    required this.onDateSelected,
    this.required = false,
    this.preventFuture = true,
    this.showAgeBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final age = selectedDate != null ? calculateAge(selectedDate!) : null;

    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? (preventFuture ? now : now),
          firstDate: DateTime(1900),
          lastDate: preventFuture ? now : DateTime(2100),
        );
        if (picked != null) {
          onDateSelected(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.calendar_today_outlined),
          suffixIcon: (showAgeBadge && age != null)
              ? Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$age yrs old',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                )
              : const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          selectedDate != null
              ? '${selectedDate!.month.toString().padLeft(2, '0')}/${selectedDate!.day.toString().padLeft(2, '0')}/${selectedDate!.year}'
              : 'Select date...',
          style: TextStyle(
            color: selectedDate != null
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Standardized numeric field with clinical unit badge
class AppNumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String unit;
  final IconData? icon;
  final double? min;
  final double? max;
  final bool required;
  final void Function(String)? onChanged;

  const AppNumberField({
    super.key,
    required this.controller,
    required this.label,
    required this.unit,
    this.icon,
    this.min,
    this.max,
    this.required = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        border: const OutlineInputBorder(),
        prefixIcon: icon != null ? Icon(icon) : null,
        suffixText: unit,
      ),
      validator: (v) {
        final trimmed = v?.trim() ?? '';
        if (required && trimmed.isEmpty) return '$label is required.';
        if (trimmed.isNotEmpty) {
          final parsed = double.tryParse(trimmed);
          if (parsed == null) return 'Enter a valid number.';
          if (min != null && parsed < min!) {
            return 'Must be at least $min $unit.';
          }
          if (max != null && parsed > max!) {
            return 'Must not exceed $max $unit.';
          }
        }
        return null;
      },
    );
  }
}

/// Generic dropdown form field
class AppDropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final IconData? icon;
  final bool required;

  const AppDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.icon,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        border: const OutlineInputBorder(),
        prefixIcon: icon != null ? Icon(icon) : null,
      ),
      validator: (v) {
        if (required && v == null) return '$label is required.';
        return null;
      },
    );
  }
}

/// Searchable dropdown selector supporting fast search-as-you-type, clear action,
/// custom item rendering, and clean modal dialog popup.
class AppSearchableDropdown<T> extends StatelessWidget {
  final String label;
  final String? hint;
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String Function(T item) itemLabel;
  final String Function(T item)? itemSubtitle;
  final Widget Function(T item)? itemLeading;
  final bool Function(T item, String query)? searchMatcher;
  final bool required;
  final bool enabled;
  final IconData? icon;
  final Widget? suffixIcon;
  final String? helperText;
  final String? Function(T?)? validator;
  final String searchHint;

  const AppSearchableDropdown({
    super.key,
    required this.label,
    this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.itemLabel,
    this.itemSubtitle,
    this.itemLeading,
    this.searchMatcher,
    this.required = false,
    this.enabled = true,
    this.icon,
    this.suffixIcon,
    this.helperText,
    this.validator,
    this.searchHint = 'Type to search...',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayText = value != null ? itemLabel(value as T) : '';

    return FormField<T>(
      initialValue: value,
      validator: (v) {
        if (required && (v == null || value == null)) {
          return '$label is required.';
        }
        if (validator != null) {
          return validator!(value);
        }
        return null;
      },
      builder: (fieldState) {
        return InkWell(
          onTap: enabled
              ? () async {
                  final picked = await showDialog<T>(
                    context: context,
                    builder: (ctx) => _SearchableDropdownModal<T>(
                      title: label,
                      items: items,
                      selectedValue: value,
                      itemLabel: itemLabel,
                      itemSubtitle: itemSubtitle,
                      itemLeading: itemLeading,
                      searchMatcher: searchMatcher,
                      searchHint: searchHint,
                    ),
                  );
                  if (picked != null) {
                    onChanged(picked);
                    fieldState.didChange(picked);
                  }
                }
              : null,
          borderRadius: BorderRadius.circular(4),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: required ? '$label *' : label,
              hintText: hint ?? 'Select $label',
              helperText: helperText,
              errorText: fieldState.errorText,
              prefixIcon: icon != null ? Icon(icon) : null,
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (value != null && !required)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      tooltip: 'Clear selection',
                      onPressed: enabled
                          ? () {
                              onChanged(null);
                              fieldState.didChange(null);
                            }
                          : null,
                    ),
                  suffixIcon ?? const Icon(Icons.arrow_drop_down),
                  const SizedBox(width: 8),
                ],
              ),
              border: const OutlineInputBorder(),
              enabled: enabled,
            ),
            child: Text(
              displayText.isNotEmpty
                  ? displayText
                  : (hint ?? 'Select $label...'),
              style: TextStyle(
                color: displayText.isNotEmpty
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }
}

class _SearchableDropdownModal<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final T? selectedValue;
  final String Function(T item) itemLabel;
  final String Function(T item)? itemSubtitle;
  final Widget Function(T item)? itemLeading;
  final bool Function(T item, String query)? searchMatcher;
  final String searchHint;

  const _SearchableDropdownModal({
    required this.title,
    required this.items,
    required this.selectedValue,
    required this.itemLabel,
    this.itemSubtitle,
    this.itemLeading,
    this.searchMatcher,
    required this.searchHint,
  });

  @override
  State<_SearchableDropdownModal<T>> createState() =>
      _SearchableDropdownModalState<T>();
}

class _SearchableDropdownModalState<T>
    extends State<_SearchableDropdownModal<T>> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final normalizedQuery = _query.trim().toLowerCase();

    final filtered = widget.items.where((item) {
      if (normalizedQuery.isEmpty) return true;
      if (widget.searchMatcher != null) {
        return widget.searchMatcher!(item, normalizedQuery);
      }
      final label = widget.itemLabel(item).toLowerCase();
      final subtitle = widget.itemSubtitle?.call(item).toLowerCase() ?? '';
      return label.contains(normalizedQuery) ||
          subtitle.contains(normalizedQuery);
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Select ${widget.title}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                onChanged: (val) => setState(() => _query = val),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Flexible(
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off_outlined,
                            size: 48,
                            color: colorScheme.outline,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No items match "$_query"',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                      ),
                      itemBuilder: (ctx, index) {
                        final item = filtered[index];
                        final isSelected = item == widget.selectedValue;
                        final subtitle = widget.itemSubtitle?.call(item);

                        return ListTile(
                          leading: widget.itemLeading?.call(item),
                          title: Text(
                            widget.itemLabel(item),
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected ? colorScheme.primary : null,
                            ),
                          ),
                          subtitle: subtitle != null ? Text(subtitle) : null,
                          trailing: isSelected
                              ? Icon(Icons.check, color: colorScheme.primary)
                              : null,
                          selected: isSelected,
                          onTap: () => Navigator.of(context).pop(item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tag and multi-selection chips input component
class AppChipsInput extends StatefulWidget {
  final String label;
  final String hint;
  final List<String> initialValues;
  final ValueChanged<List<String>> onChanged;
  final IconData? icon;

  const AppChipsInput({
    super.key,
    required this.label,
    this.hint = 'Type and press Enter to add',
    this.initialValues = const [],
    required this.onChanged,
    this.icon,
  });

  @override
  State<AppChipsInput> createState() => _AppChipsInputState();
}

class _AppChipsInputState extends State<AppChipsInput> {
  late final List<String> _values;
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _values = List.from(widget.initialValues);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _add(String value) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty && !_values.contains(trimmed)) {
      setState(() {
        _values.add(trimmed);
        widget.onChanged(_values);
        _textController.clear();
      });
    }
  }

  void _remove(String value) {
    setState(() {
      _values.remove(value);
      widget.onChanged(_values);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (_values.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _values.map((v) {
                return Chip(
                  label: Text(v, style: const TextStyle(fontSize: 12)),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () => _remove(v),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _textController,
            decoration: InputDecoration(
              hintText: widget.hint,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.add, size: 18),
                onPressed: () => _add(_textController.text),
              ),
            ),
            onSubmitted: _add,
          ),
        ],
      ),
    );
  }
}

/// Specialized clinical vitals field with unit badge and contextual range warning
class AppVitalsField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String unit;
  final IconData? icon;
  final double? min;
  final double? max;
  final bool required;
  final String? Function(String?)? contextualWarning;
  final void Function(String)? onChanged;

  const AppVitalsField({
    super.key,
    required this.controller,
    required this.label,
    required this.unit,
    this.icon,
    this.min,
    this.max,
    this.required = false,
    this.contextualWarning,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final warning = contextualWarning?.call(controller.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (v) {
            onChanged?.call(v);
          },
          decoration: InputDecoration(
            labelText: required ? '$label *' : label,
            border: const OutlineInputBorder(),
            prefixIcon: icon != null ? Icon(icon) : null,
            suffixText: unit,
          ),
          validator: (v) {
            final trimmed = v?.trim() ?? '';
            if (required && trimmed.isEmpty) return '$label is required.';
            if (trimmed.isNotEmpty) {
              final parsed = double.tryParse(trimmed);
              if (parsed == null) return 'Enter a valid number.';
              if (min != null && parsed < min!) {
                return 'Must be at least $min $unit.';
              }
              if (max != null && parsed > max!) {
                return 'Must not exceed $max $unit.';
              }
            }
            return null;
          },
        ),
        if (warning != null && warning.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.amber.shade700, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 12,
                  color: Colors.amber.shade900,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    warning,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Double-submission locked submit button
class AppAsyncSubmitButton extends StatelessWidget {
  final String label;
  final String loadingLabel;
  final IconData? icon;
  final bool isSubmitting;
  final Future<void> Function()? onPressed;
  final Color? backgroundColor;

  const AppAsyncSubmitButton({
    super.key,
    required this.label,
    this.loadingLabel = 'Saving...',
    this.icon,
    required this.isSubmitting,
    required this.onPressed,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: backgroundColor != null
          ? FilledButton.styleFrom(backgroundColor: backgroundColor)
          : null,
      onPressed: isSubmitting ? null : onPressed,
      icon: isSubmitting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : (icon != null ? Icon(icon) : const SizedBox.shrink()),
      label: Text(isSubmitting ? loadingLabel : label),
    );
  }
}

/// Clinical range constants and evaluation helpers
class ClinicalRanges {
  static String? evaluateBP(double? systolic, double? diastolic) {
    if (systolic == null || diastolic == null) return null;
    if (systolic >= 180 || diastolic >= 120) {
      return 'CRITICAL: Hypertensive Crisis (>=180/120)';
    }
    if (systolic >= 140 || diastolic >= 90) {
      return 'Stage 2 Hypertension (>=140/90)';
    }
    if (systolic >= 130 || diastolic >= 80) {
      return 'Stage 1 Hypertension (>=130/80)';
    }
    if (systolic < 90 || diastolic < 60) {
      return 'Hypotension (<90/60)';
    }
    return null;
  }

  static String? evaluateTemp(double? temp) {
    if (temp == null) return null;
    if (temp >= 39.0) return 'High Fever (>=39.0°C)';
    if (temp >= 37.8) return 'Mild Pyrexia (>=37.8°C)';
    if (temp < 35.5) return 'Hypothermia (<35.5°C)';
    return null;
  }

  static String? evaluateHR(double? hr) {
    if (hr == null) return null;
    if (hr > 120) return 'Severe Tachycardia (>120 bpm)';
    if (hr > 100) return 'Tachycardia (>100 bpm)';
    if (hr < 50) return 'Bradycardia (<50 bpm)';
    return null;
  }

  static String? evaluateRR(double? rr) {
    if (rr == null) return null;
    if (rr > 24) return 'Tachypnea (>24 cpm)';
    if (rr < 10) return 'Bradypnea (<10 cpm)';
    return null;
  }

  static String? evaluateSpO2(double? o2) {
    if (o2 == null) return null;
    if (o2 < 90) return 'CRITICAL: Severe Hypoxemia (<90%)';
    if (o2 < 95) return 'Mild Hypoxia (<95%)';
    return null;
  }

  static double? calculateBMI(double? weightKg, double? heightCm) {
    if (weightKg == null || heightCm == null || heightCm <= 0) return null;
    final heightM = heightCm / 100.0;
    return double.parse((weightKg / (heightM * heightM)).toStringAsFixed(1));
  }

  static String? classifyBMI(double? bmi) {
    if (bmi == null) return null;
    if (bmi < 18.5) return 'Underweight (<18.5)';
    if (bmi < 23.0) return 'Normal (18.5 - 22.9)';
    if (bmi < 25.0) return 'Overweight (23.0 - 24.9)';
    return 'Obese (>=25.0)';
  }
}

/// Helper function to calculate age from birth date
int calculateAge(DateTime birthDate) {
  final now = DateTime.now();
  var age = now.year - birthDate.year;
  if (now.month < birthDate.month ||
      (now.month == birthDate.month && now.day < birthDate.day)) {
    age--;
  }
  return age >= 0 ? age : 0;
}
