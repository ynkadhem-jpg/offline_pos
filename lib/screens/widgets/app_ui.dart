import 'package:flutter/material.dart';

import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_radius.dart';
import '../../design_system/tokens/app_spacing.dart';

enum AppStatusTone { neutral, success, warning, error, info, accent }

class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    required this.title,
    this.subtitle,
    this.action,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: textTheme.headlineSmall),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle!,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (action == null) return titleBlock;

          if (constraints.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                titleBlock,
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: action!,
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: titleBlock),
              const SizedBox(width: AppSpacing.md),
              action!,
            ],
          );
        },
      ),
    );
  }
}

class AppPanel extends StatelessWidget {
  const AppPanel({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.backgroundColor = AppColors.surfaceCard,
    this.borderColor = AppColors.border,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class AppHeroCard extends StatelessWidget {
  const AppHeroCard({
    required this.label,
    required this.value,
    required this.icon,
    this.subtitle,
    this.action,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.card),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [AppColors.primary, AppColors.primaryHover],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.20),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            end: -28,
            top: -34,
            child: _SoftOrb(
              size: 142,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          PositionedDirectional(
            start: -24,
            bottom: -44,
            child: _SoftOrb(
              size: 124,
              color: AppColors.accent.withValues(alpha: 0.18),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _IconTile(
                    icon: icon,
                    background: Colors.white.withValues(alpha: 0.13),
                    foreground: Colors.white,
                  ),
                  const Spacer(),
                  if (action != null) action!,
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                label,
                style: textTheme.labelLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.76),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  subtitle!,
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class AppMetricCard extends StatelessWidget {
  const AppMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.tone = AppStatusTone.neutral,
    this.compact = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final AppStatusTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = _toneColors(tone);

    return AppPanel(
      padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconTile(
                icon: icon,
                size: compact ? 38 : 44,
                background: colors.background,
                foreground: colors.foreground,
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colors.foreground,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (compact ? textTheme.labelMedium : textTheme.labelLarge)
                ?.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: compact ? textTheme.titleMedium : textTheme.titleLarge,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    required this.label,
    this.tone = AppStatusTone.neutral,
    this.icon,
    super.key,
  });

  final String label;
  final AppStatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = _toneColors(tone);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: colors.foreground.withValues(alpha: 0.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.rg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: colors.foreground),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppFilterPill extends StatelessWidget {
  const AppFilterPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.tone = AppStatusTone.neutral,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final AppStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = _toneColors(tone);

    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: Icon(
        icon,
        size: 18,
        color: selected ? colors.foreground : AppColors.inkMuted,
      ),
      label: Text(label),
      selectedColor: colors.background,
      backgroundColor: AppColors.surfaceMuted,
      side: BorderSide(
        color: selected ? colors.foreground : AppColors.border,
      ),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: selected ? colors.foreground : AppColors.inkMuted,
          ),
    );
  }
}

class AppResponsiveWrap extends StatelessWidget {
  const AppResponsiveWrap({
    required this.children,
    required this.wideColumns,
    this.mediumColumns = 2,
    this.spacing = AppSpacing.md,
    super.key,
  });

  final List<Widget> children;
  final int wideColumns;
  final int mediumColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? wideColumns
            : constraints.maxWidth >= 700
                ? mediumColumns
                : 1;
        final width = (constraints.maxWidth - spacing * (columns - 1)) /
            columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    required this.title,
    this.icon,
    this.action,
    this.subtitle,
    super.key,
  });

  final String title;
  final IconData? icon;
  final Widget? action;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          _IconTile(
            icon: icon!,
            size: 40,
            background: AppColors.surfaceMuted,
            foreground: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.rg),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.titleMedium),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle!,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: AppSpacing.sm),
          action!,
        ],
      ],
    );
  }
}

class AppListCard extends StatelessWidget {
  const AppListCard({
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.tone = AppStatusTone.neutral,
    super.key,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final AppStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = _toneColors(tone);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.rg),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: SizedBox.square(
              dimension: 42,
              child: Center(child: leading),
            ),
          ),
          const SizedBox(width: AppSpacing.rg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.icon,
    required this.title,
    this.description,
    this.action,
    this.compact = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final iconSize = compact ? 50.0 : 72.0;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Icon(
                  icon,
                  size: compact ? 26 : 34,
                  color: AppColors.accent,
                ),
              ),
              SizedBox(height: compact ? AppSpacing.rg : AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: textTheme.titleSmall,
              ),
              if (description != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  description!,
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: AppSpacing.lg),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.icon,
    required this.background,
    required this.foreground,
    this.size = 44,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(icon, color: foreground, size: size * 0.52),
    );
  }
}

class _SoftOrb extends StatelessWidget {
  const _SoftOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

({Color background, Color foreground}) _toneColors(AppStatusTone tone) {
  return switch (tone) {
    AppStatusTone.success => (
      background: AppColors.successSoft,
      foreground: AppColors.success,
    ),
    AppStatusTone.warning => (
      background: AppColors.warningSoft,
      foreground: AppColors.warning,
    ),
    AppStatusTone.error => (
      background: AppColors.errorSoft,
      foreground: AppColors.error,
    ),
    AppStatusTone.info => (
      background: AppColors.infoSoft,
      foreground: AppColors.info,
    ),
    AppStatusTone.accent => (
      background: AppColors.accentSoft,
      foreground: AppColors.accent,
    ),
    AppStatusTone.neutral => (
      background: AppColors.surfaceTint,
      foreground: AppColors.primary,
    ),
  };
}
