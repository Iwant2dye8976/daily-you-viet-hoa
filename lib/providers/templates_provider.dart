// Copyright (C) 2026 Demizo and contributors
// SPDX-License-Identifier: GPL-3.0-only
// Additional terms under GPLv3 section 7 apply; see ADDITIONAL_TERMS.md.

import 'dart:async';
import 'package:daily_you/config_provider.dart';
import 'package:daily_you/l10n/generated/app_localizations.dart';
import 'package:daily_you/database/app_database.dart';
import 'package:daily_you/database/template_dao.dart';
import 'package:daily_you/models/template.dart';
import 'package:daily_you/providers/tags_provider.dart';
import 'package:material_ui/material_ui.dart';

class TemplatesProvider with ChangeNotifier {
  static final TemplatesProvider instance = TemplatesProvider._init();

  TemplatesProvider._init();

  List<Template> templates = List.empty(growable: true);

  /// Load the provider's data from the app database
  Future<void> load() async {
    templates = await TemplateDao.getAll();

    bool changed = false;
    for (int i = 0; i < templates.length; i++) {
      final t = templates[i];
      if (t.name == 'Timestamp') {
        final updated = t.copy(name: 'Dấu thời gian');
        await TemplateDao.update(updated);
        templates[i] = updated;
        changed = true;
      } else if (t.name == 'Day Summary') {
        final newText = (t.text == null || t.text!.contains('### Summary'))
            ? "### Tổng kết\n- \n\n### Trích dẫn\n> "
            : t.text;
        final updated = t.copy(name: 'Tổng kết ngày', text: newText);
        await TemplateDao.update(updated);
        templates[i] = updated;
        changed = true;
      } else if (t.name == 'Reflection') {
        final newText = (t.text == null ||
                t.text!.contains('What did you enjoy today?'))
            ? "### Điều gì làm bạn cảm thấy thích thú hôm nay?\n- \n\n### Bạn biết ơn vì điều gì?\n- \n\n### Bạn đang mong chờ điều gì?\n- "
            : t.text;
        final updated = t.copy(name: 'Nhìn lại', text: newText);
        await TemplateDao.update(updated);
        templates[i] = updated;
        changed = true;
      }
    }

    if (changed) {
      await AppDatabase.instance.updateExternalDatabase();
    }

    notifyListeners();
  }

  // CRUD operations

  Future<Template> add(Template template) async {
    // Insert the template into the database so that it has an ID
    final templateWithId = await TemplateDao.add(template);
    templates.add(templateWithId);
    await AppDatabase.instance.updateExternalDatabase();
    notifyListeners();
    return templateWithId;
  }

  Future<void> remove(Template template) async {
    await TagsProvider.instance.removeAllTemplateTagsForTemplate(template.id!);
    await TemplateDao.remove(template.id!);
    templates.removeWhere((x) => x.id == template.id);
    await AppDatabase.instance.updateExternalDatabase();
    notifyListeners();
  }

  Future<void> update(Template template) async {
    await TemplateDao.update(template);
    final index = templates.indexWhere((x) => x.id == template.id);
    templates[index] = template;
    await AppDatabase.instance.updateExternalDatabase();
    notifyListeners();
  }

  Template? getDefaultTemplate() {
    var defaultTemplateId =
        ConfigProvider.instance.get(Settings.defaultTemplate);
    return templates.where((t) => t.id == defaultTemplateId).firstOrNull;
  }

  Future<void> createDefaultTemplates() async {
    final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
    final defaultTemplates = [
      Template(
          name: l10n.templateDefaultTimestampTitle,
          text: l10n.templateDefaultTimestampBody("{{date}}", "{{time}}"),
          timeCreate: DateTime.now(),
          timeModified: DateTime.now()),
      Template(
          name: l10n.templateDefaultSummaryTitle,
          text: l10n.templateDefaultSummaryBody,
          timeCreate: DateTime.now(),
          timeModified: DateTime.now()),
      Template(
          name: l10n.templateDefaultReflectionTitle,
          text: l10n.templateDefaultReflectionBody,
          timeCreate: DateTime.now(),
          timeModified: DateTime.now()),
    ];

    for (final template in defaultTemplates) {
      await add(template);
    }
  }
}
