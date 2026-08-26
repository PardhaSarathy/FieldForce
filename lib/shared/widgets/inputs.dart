import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';

/// A labelled field wrapper.
///
/// The label sits *above* the control rather than floating inside it. In dense
/// enterprise forms a floating label disappears once filled, which makes a
/// 12-field form unreadable on review — a real problem for the multi-step
/// activity flow (§18).
class FieldShell extends StatelessWidget {
  const FieldShell({
    super.key,
    required this.child,
    this.label,
    this.required = false,
    this.helper,
    this.error,
  });

  final Widget child;
  final String? label;
  final bool required;
  final String? helper;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Row(
            children: [
              // Flexible: a long label at a large font size would otherwise
              // push the required marker past the edge of the field.
              Flexible(
                child: Text(
                  label!,
                  style: AppTypography.bodySm,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (required)
                Text(
                  ' *',
                  style: AppTypography.bodySm.copyWith(color: AppColors.error),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        child,
        if (error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, size: 13, color: AppColors.error),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  error!,
                  style: AppTypography.caption.copyWith(color: AppColors.error),
                ),
              ),
            ],
          ),
        ] else if (helper != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(helper!, style: AppTypography.caption),
        ],
      ],
    );
  }
}

/// Standard text input. Validation is inline and eager-after-first-submit
/// (§63): we do not wait until the end of a four-step form to reveal errors.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.initialValue,
    this.onChanged,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.required = false,
    this.enabled = true,
    this.helper,
    this.prefixIcon,
    this.suffix,
    this.obscureText = false,
    this.textCapitalization = TextCapitalization.sentences,
    this.inputFormatters,
    this.autofocus = false,
    this.textInputAction,
    this.onSubmitted,
  });

  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;
  final bool required;
  final bool enabled;
  final String? helper;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool obscureText;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return FieldShell(
      label: label,
      required: required,
      helper: helper,
      child: TextFormField(
        controller: controller,
        initialValue: initialValue,
        onChanged: onChanged,
        validator: validator,
        keyboardType: keyboardType,
        maxLines: obscureText ? 1 : maxLines,
        maxLength: maxLength,
        enabled: enabled,
        obscureText: obscureText,
        autofocus: autofocus,
        textInputAction: textInputAction,
        onFieldSubmitted: onSubmitted,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        style: AppTypography.body,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(
          hintText: hint,
          counterText: '',
          fillColor: enabled ? AppColors.surface : AppColors.surfaceSecondary,
          prefixIcon: prefixIcon == null
              ? null
              : Icon(prefixIcon, size: AppSizes.iconMd,
                  color: AppColors.textSecondary),
          suffixIcon: suffix,
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: maxLines > 1 ? AppSpacing.md : AppSpacing.md,
          ),
        ),
      ),
    );
  }
}

/// Search input used in list headers. Debouncing is the caller's concern.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    this.hint = 'Search',
    this.controller,
    this.onChanged,
    this.onClear,
    this.autofocus = false,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final hasText = controller?.text.isNotEmpty ?? false;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      autofocus: autofocus,
      style: AppTypography.body,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search,
            size: AppSizes.iconLg, color: AppColors.textSecondary),
        suffixIcon: hasText
            ? IconButton(
                icon: const Icon(Icons.close, size: AppSizes.iconMd),
                color: AppColors.textSecondary,
                onPressed: () {
                  controller?.clear();
                  onChanged?.call('');
                  onClear?.call();
                },
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      ),
    );
  }
}

/// Typed dropdown. Generic so callers keep their enum/model type end to end
/// instead of round-tripping through strings.
class DropdownField<T> extends StatelessWidget {
  const DropdownField({
    super.key,
    required this.items,
    required this.itemLabel,
    this.value,
    this.onChanged,
    this.label,
    this.hint = 'Select',
    this.required = false,
    this.enabled = true,
    this.helper,
    this.validator,
  });

  final List<T> items;
  final String Function(T) itemLabel;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final String? label;
  final String hint;
  final bool required;
  final bool enabled;
  final String? helper;
  final String? Function(T?)? validator;

  @override
  Widget build(BuildContext context) {
    return FieldShell(
      label: label,
      required: required,
      helper: helper,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        onChanged: enabled ? onChanged : null,
        validator: validator,
        isExpanded: true,
        style: AppTypography.body,
        icon: const Icon(Icons.keyboard_arrow_down,
            color: AppColors.textSecondary),
        dropdownColor: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        hint: Text(hint,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
        decoration: InputDecoration(
          fillColor: enabled ? AppColors.surface : AppColors.surfaceSecondary,
        ),
        items: [
          for (final item in items)
            DropdownMenuItem(
              value: item,
              child: Text(itemLabel(item), overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
    );
  }
}

/// Tap-to-open date picker rendered as a field.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.required = false,
    this.firstDate,
    this.lastDate,
    this.hint = 'Select date',
    this.enabled = true,
    this.helper,
  });

  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final String? label;
  final bool required;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String hint;
  final bool enabled;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return _PickerField(
      label: label,
      required: required,
      helper: helper,
      enabled: enabled,
      icon: Icons.calendar_today_outlined,
      text: value == null ? hint : Fmt.date(value!),
      isPlaceholder: value == null,
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: firstDate ?? DateTime(now.year - 2),
          lastDate: lastDate ?? DateTime(now.year + 2),
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}

/// Tap-to-open time picker rendered as a field.
class TimeField extends StatelessWidget {
  const TimeField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.required = false,
    this.hint = 'Select time',
    this.enabled = true,
    this.helper,
  });

  final TimeOfDay? value;
  final ValueChanged<TimeOfDay> onChanged;
  final String? label;
  final bool required;
  final String hint;
  final bool enabled;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return _PickerField(
      label: label,
      required: required,
      helper: helper,
      enabled: enabled,
      icon: Icons.schedule_outlined,
      text: value == null ? hint : value!.format(context),
      isPlaceholder: value == null,
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: value ?? TimeOfDay.now(),
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.text,
    required this.icon,
    required this.onTap,
    required this.isPlaceholder,
    required this.enabled,
    this.label,
    this.required = false,
    this.helper,
  });

  final String text;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPlaceholder;
  final bool enabled;
  final String? label;
  final bool required;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return FieldShell(
      label: label,
      required: required,
      helper: helper,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          height: AppSizes.fieldHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: enabled ? AppColors.surface : AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: AppTypography.body.copyWith(
                    color: isPlaceholder
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              Icon(icon, size: AppSizes.iconMd, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Amount input with a rupee affordance and digit-only formatting.
class CurrencyField extends StatelessWidget {
  const CurrencyField({
    super.key,
    this.label,
    this.controller,
    this.onChanged,
    this.required = false,
    this.hint = '0',
    this.enabled = true,
    this.helper,
    this.validator,
  });

  final String? label;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool required;
  final String hint;
  final bool enabled;
  final String? helper;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return FieldShell(
      label: label,
      required: required,
      helper: helper,
      child: TextFormField(
        controller: controller,
        onChanged: onChanged,
        validator: validator,
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
        ],
        style: AppTypography.numeric.copyWith(fontSize: 16),
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.sm),
            child: Text('₹', style: AppTypography.titleMd),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          fillColor: enabled ? AppColors.surface : AppColors.surfaceSecondary,
        ),
      ),
    );
  }
}

/// Whole-number input with stepper affordances, for order quantities.
class QuantityField extends StatelessWidget {
  const QuantityField({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 99999,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove,
            onTap: value > min ? () => onChanged(value - 1) : null,
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 44),
            alignment: Alignment.center,
            child: Text('$value', style: AppTypography.numeric),
          ),
          _StepButton(
            icon: Icons.add,
            onTap: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(
          icon,
          size: AppSizes.iconMd,
          color: onTap == null ? AppColors.border : AppColors.brand,
        ),
      ),
    );
  }
}

/// Horizontally scrolling filter row used above every list in the app.
class FilterChipBar<T> extends StatelessWidget {
  const FilterChipBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.labelOf,
    this.countOf,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
  });

  final List<T> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final String Function(T) labelOf;

  /// Optional badge count rendered next to the label, e.g. "Pending 3".
  final int? Function(T)? countOf;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final option = options[index];
          final isSelected = option == selected;
          final count = countOf?.call(option);

          return GestureDetector(
            onTap: () => onSelected(option),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.brand : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: isSelected ? AppColors.brand : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    labelOf(option),
                    style: AppTypography.titleSm.copyWith(
                      color: isSelected
                          ? AppColors.textOnBrand
                          : AppColors.textPrimary,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  if (count != null && count > 0) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.22)
                            : AppColors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '$count',
                        style: AppTypography.badge.copyWith(
                          color: isSelected
                              ? AppColors.textOnBrand
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Equal-width segmented control for two or three mutually exclusive views.
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.labelOf,
  });

  final List<T> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final String Function(T) labelOf;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelected(option),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: option == selected
                        ? AppColors.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    labelOf(option),
                    style: AppTypography.titleSm.copyWith(
                      color: option == selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Reusable validators (§63).
abstract final class Validate {
  static String? required(String? value, [String field = 'This field']) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  /// Indian mobile numbers: 10 digits starting 6–9, tolerating +91 and spaces.
  static String? mobile(String? value, {bool isRequired = true}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return isRequired ? 'Mobile number is required' : null;
    final digits = v.replaceAll(RegExp(r'[^\d]'), '');
    final local = digits.length > 10 ? digits.substring(digits.length - 10) : digits;
    if (local.length != 10 || !RegExp(r'^[6-9]').hasMatch(local)) {
      return 'Enter a valid 10-digit mobile number';
    }
    return null;
  }

  static String? email(String? value, {bool isRequired = false}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return isRequired ? 'Email is required' : null;
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(v)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? amount(String? value, {bool isRequired = true, double max = 1000000}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return isRequired ? 'Amount is required' : null;
    final parsed = double.tryParse(v);
    if (parsed == null) return 'Enter a valid amount';
    if (parsed <= 0) return 'Amount must be greater than zero';
    if (parsed > max) return 'Amount exceeds the permitted limit';
    return null;
  }

  /// Validates that [end] is not before [start].
  static String? dateRange(DateTime? start, DateTime? end) {
    if (start == null || end == null) return null;
    if (end.isBefore(start)) return 'End date cannot be before the start date';
    return null;
  }
}
