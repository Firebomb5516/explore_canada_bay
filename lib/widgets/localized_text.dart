import 'package:flutter/material.dart' as material;

import '../l10n/app_localizations.dart';

/// Drop-in [material.Text] that localises registered interface literals.
///
/// JSON-backed proper names remain untouched because only explicitly
/// registered interface phrases are translated.
class Text extends material.Text {
  const Text(
    super.data, {
    super.key,
    super.style,
    super.strutStyle,
    super.textAlign,
    super.textDirection,
    super.locale,
    super.softWrap,
    super.overflow,
    super.textScaler,
    super.maxLines,
    super.semanticsLabel,
    super.textWidthBasis,
    super.textHeightBehavior,
    super.selectionColor,
  });

  const Text.rich(
    super.textSpan, {
    super.key,
    super.style,
    super.strutStyle,
    super.textAlign,
    super.textDirection,
    super.locale,
    super.softWrap,
    super.overflow,
    super.textScaler,
    super.maxLines,
    super.semanticsLabel,
    super.textWidthBasis,
    super.textHeightBehavior,
    super.selectionColor,
  }) : super.rich();

  @override
  material.Widget build(material.BuildContext context) {
    final strings = AppLocalizations.of(context);
    final richSource = textSpan;
    if (richSource != null) {
      final defaults = material.DefaultTextStyle.of(context);
      final effectiveStyle = defaults.style.merge(style);
      final translated = _translateInlineSpan(strings, richSource);
      final richText = material.RichText(
        text: material.TextSpan(style: effectiveStyle, children: [translated]),
        strutStyle: strutStyle,
        textAlign: textAlign ?? defaults.textAlign ?? material.TextAlign.start,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap ?? defaults.softWrap,
        overflow: overflow ?? defaults.overflow,
        textScaler: textScaler ?? material.MediaQuery.textScalerOf(context),
        maxLines: maxLines ?? defaults.maxLines,
        textWidthBasis: textWidthBasis ?? defaults.textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
      final label = semanticsLabel;
      if (label == null) return richText;
      return material.Semantics(
        textDirection: textDirection,
        label: strings.literal(label),
        child: material.ExcludeSemantics(child: richText),
      );
    }

    final source = data;
    if (source == null) return super.build(context);
    final defaults = material.DefaultTextStyle.of(context);
    final effectiveStyle = defaults.style.merge(style);
    final richText = material.RichText(
      text: material.TextSpan(
        text: strings.literal(source),
        style: effectiveStyle,
      ),
      strutStyle: strutStyle,
      textAlign: textAlign ?? defaults.textAlign ?? material.TextAlign.start,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap ?? defaults.softWrap,
      overflow: overflow ?? defaults.overflow,
      textScaler: textScaler ?? material.MediaQuery.textScalerOf(context),
      maxLines: maxLines ?? defaults.maxLines,
      textWidthBasis: textWidthBasis ?? defaults.textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
    final label = semanticsLabel;
    if (label == null) return richText;
    return material.Semantics(
      textDirection: textDirection,
      label: strings.literal(label),
      child: material.ExcludeSemantics(child: richText),
    );
  }
}

material.InlineSpan _translateInlineSpan(
  AppLocalizations strings,
  material.InlineSpan source,
) {
  if (source is! material.TextSpan) return source;
  return material.TextSpan(
    text: source.text == null ? null : strings.literal(source.text!),
    children: source.children
        ?.map((child) => _translateInlineSpan(strings, child))
        .toList(growable: false),
    style: source.style,
    recognizer: source.recognizer,
    mouseCursor: source.mouseCursor,
    onEnter: source.onEnter,
    onExit: source.onExit,
    semanticsLabel: source.semanticsLabel == null
        ? null
        : strings.literal(source.semanticsLabel!),
    locale: source.locale,
    spellOut: source.spellOut,
  );
}
