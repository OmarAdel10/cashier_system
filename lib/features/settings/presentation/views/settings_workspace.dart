import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';

class SettingsWorkspace extends StatefulWidget {
  const SettingsWorkspace({super.key});

  @override
  State<SettingsWorkspace> createState() => _SettingsWorkspaceState();
}

class _SettingsWorkspaceState extends State<SettingsWorkspace>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'General'),
            Tab(text: 'Appearance'),
            Tab(text: 'Localization'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _GeneralTab(),
          _AppearanceTab(),
          _LocalizationTab(),
        ],
      ),
    );
  }
}

class _GeneralTab extends StatelessWidget {
  const _GeneralTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Store Name',
                  border: OutlineInputBorder(),
                ),
                controller: TextEditingController.fromValue(
                  TextEditingValue(
                    text: state.settings.storeName,
                    selection: TextSelection.collapsed(
                      offset: state.settings.storeName.length,
                    ),
                  ),
                ),
                onChanged: (value) {
                  context.read<SettingsBloc>().add(
                        StoreNameChanged(value),
                      );
                },
              ),
              const SizedBox(height: 24),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Receipt Footnote',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                controller: TextEditingController.fromValue(
                  TextEditingValue(
                    text: state.settings.receiptFootnote,
                    selection: TextSelection.collapsed(
                      offset: state.settings.receiptFootnote.length,
                    ),
                  ),
                ),
                onChanged: (value) {
                  context.read<SettingsBloc>().add(
                        ReceiptFootnoteChanged(value),
                      );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AppearanceTab extends StatelessWidget {
  const _AppearanceTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: Text(
              state.settings.isDarkMode ? 'Dark theme active' : 'Light theme active',
            ),
            value: state.settings.isDarkMode,
            onChanged: (value) {
              context.read<SettingsBloc>().add(ThemeToggled(value));
            },
          ),
        );
      },
    );
  }
}

class _LocalizationTab extends StatelessWidget {
  const _LocalizationTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Language',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'ar', label: Text('Arabic')),
                  ButtonSegment(value: 'en', label: Text('English')),
                ],
                selected: {state.settings.languageCode},
                onSelectionChanged: (selection) {
                  context.read<SettingsBloc>().add(
                        LanguageToggled(selection.first),
                      );
                },
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        state.settings.isRtl
                            ? 'Arabic mode: The interface will flip to RTL layout'
                            : 'English mode: The interface will use LTR layout',
                        style: TextStyle(color: Colors.blue.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
