
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

void main() => runApp(const CoachSplitApp());

class CoachSplitApp extends StatelessWidget {
  const CoachSplitApp({super.key});


  String _formatClock(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    final pages = [_setupPage(), _startPage(), _capturePage(), _resultsPage()];
    final width = MediaQuery.of(context).size.width;
    final maxContentWidth = width >= 900 ? 760.0 : double.infinity;

    final content = Column(children: [
      _Stats(event: event),
      _Nav(selected: _page, onChanged: _selectPage),
      Expanded(child: IndexedStack(index: _page, children: pages)),
    ]);

    return Scaffold(
      appBar: AppBar(title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('CoachSplit 1.0.1'),
        Text(event == null ? 'Kein Bewerb' : '${event.name} · ${event.intervalSeconds}s · ${event.compareByCategory ? 'AK' : 'Alle'}', style: Theme.of(context).textTheme.bodySmall),
      ])),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _setupPage() => ListView(padding: const EdgeInsets.all(12), children: [
        _Section(title: 'Bewerbe', subtitle: 'zuhause vorbereiten, vor Ort laden', child: Column(children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _newEvent,
                  icon: const Icon(Icons.add),
                  label: const Text('Neuer Bewerb'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_savedEvents.isEmpty) const ListTile(title: Text('Noch keine gespeicherten Bewerbe')),
          for (final event in _savedEvents.values)
            Card(child: ListTile(title: Text(event.name), subtitle: Text('${event.athletes.length} Athleten · ${event.points.length} Messpunkte'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _deleteEvent(event.name)), const Icon(Icons.chevron_right)]), onTap: () => _loadEvent(event))),

          if (_archivedEvents.isNotEmpty)
            ExpansionTile(
              title: const Text('Archiv'),
              subtitle: Text('${_archivedEvents.length} Bewerbe'),
              children: [
                for (final event in _archivedEvents.values)
                  ListTile(
                    title: Text(event.name),
                    subtitle: Text('${event.athletes.length} Athleten · ${event.points.length} Messpunkte'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'view') _viewArchivedEvent(event);
                        if (value == 'template') _loadTemplateFromArchived(event);
                        if (value == 'delete') _deleteArchivedEvent(event.name);
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'view', child: Text('Einsehen')),
                        PopupMenuItem(value: 'template', child: Text('Als Vorlage verwenden')),
                        PopupMenuItem(value: 'delete', child: Text('Löschen')),
                      ],
                    ),
                    onTap: () => _viewArchivedEvent(event),
                  ),
              ],
            ),
        ])),
        _Section(title: 'Bewerb bearbeiten', subtitle: 'Startzeit, Startliste und Messpunkte', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(controller: _eventName, decoration: const InputDecoration(labelText: 'Bewerb / Training'), onChanged: (_) => _scheduleSetupAutosave()),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () async {
              final picked = await showTimePicker(context: context, initialTime: _firstStartTime);
              if (picked != null) { setState(() => _firstStartTime = picked); _scheduleSetupAutosave(); }
            }, icon: const Icon(Icons.schedule), label: Text('Start: ${_formatTimeOfDay24(_firstStartTime)}'))),
            const SizedBox(width: 8),
            DropdownButton<int>(value: _intervalSeconds, items: const [DropdownMenuItem(value: 15, child: Text('15s')), DropdownMenuItem(value: 30, child: Text('30s')), DropdownMenuItem(value: 60, child: Text('60s'))], onChanged: (v) {
              if (v != null) { setState(() => _intervalSeconds = v); _scheduleSetupAutosave(); }
            }),
          ]),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _prepareStartTimesInSetup,
            icon: const Icon(Icons.schedule),
            label: const Text('Startzeiten übernehmen'),
          ),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Altersklassen getrennt werten'), subtitle: const Text('Auch in Ergebnisansicht umschaltbar'), value: _compareByCategory, onChanged: (v) { setState(() => _compareByCategory = v); _scheduleSetupAutosave(); }),
          TextField(controller: _athletesText, maxLines: 8, onChanged: (_) => _scheduleSetupAutosave(), decoration: const InputDecoration(labelText: 'Athleten im Bewerb', hintText: '12, Max, U12m, *', alignLabelWithHint: true)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: _csvImportDialog, icon: const Icon(Icons.table_chart), label: const Text('CSV importieren')),
            OutlinedButton.icon(onPressed: _addSplitPointFromSetup, icon: const Icon(Icons.add_location_alt), label: const Text('Messpunkt hinzufügen')),
          ]),
          const SizedBox(height: 8),
          TextField(controller: _pointsText, maxLines: 5, onChanged: (_) => _scheduleSetupAutosave(), decoration: const InputDecoration(labelText: 'Messpunkte', hintText: 'Anstieg, split\nZiel, ziel', alignLabelWithHint: true)),
          const SizedBox(height: 12),
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: _goToStart, icon: const Icon(Icons.arrow_forward), label: const Text('Zum Start')),
        ])),
        _Section(title: 'Meine Standardathleten', subtitle: 'Gruppen einklappbar, dauerhaft speicherbar', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final entry in _parseGroups().entries)
            ExpansionTile(title: Text(entry.key), subtitle: Text('${entry.value.split('\n').where((l) => l.trim().isNotEmpty).length} Athleten'), children: [
              Padding(padding: const EdgeInsets.all(8), child: Text(entry.value)),
              Wrap(spacing: 8, children: [
                OutlinedButton(onPressed: () => _loadGroup(entry.value), child: const Text('Als Startliste')),
                OutlinedButton(onPressed: () => _loadGroup(entry.value, append: true), child: const Text('Ergänzen')),
              ]),
              const SizedBox(height: 8),
            ]),
          const SizedBox(height: 8),
          TextField(controller: _groupsText, maxLines: 10, decoration: const InputDecoration(labelText: 'Gruppen bearbeiten', hintText: '[U12]\n12, Max, U12m, *', alignLabelWithHint: true)),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _saveGroups, icon: const Icon(Icons.save), label: const Text('Standardgruppen speichern')),
        ]))
      ]);

  Widget _startPage() {
    final event = _event;
    if (event == null) return const Center(child: Text('Kein Bewerb geladen'));
    final waiting = event.athletes.where((a) => a.status == AthleteStatus.waiting).take(15).toList();
    final running = event.athletes.where((a) => a.status == AthleteStatus.running).toList();
    final finished = event.athletes.where((a) => a.status == AthleteStatus.finished).toList().reversed.take(5).toList();
    return ListView(padding: const EdgeInsets.all(12), children: [
      _Section(title: 'Startliste', subtitle: 'Countdown + manueller Start + Massenstart bis 15', child: Column(children: [
        if (waiting.isNotEmpty) Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _massStart,
                icon: const Icon(Icons.groups),
                label: Text('Massenstart (${min(15, waiting.length)})'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _autoStartEnabled = !_autoStartEnabled),
                icon: Icon(_autoStartEnabled ? Icons.timer : Icons.timer_off),
                label: Text(_autoStartEnabled ? 'AutoStart EIN' : 'AutoStart AUS'),
              ),
            ),
          ]),
        ),
        if (waiting.isEmpty) const ListTile(title: Text('Alle Athleten gestartet')),
        for (final athlete in waiting) _StartRow(athlete: athlete, autoStartEnabled: _autoStartEnabled, onStart: () => _manualStart(athlete)),
      ])),
      _Section(title: 'Unterwegs', subtitle: 'letzter bekannter Stand', child: Column(children: [
        if (running.isEmpty) const ListTile(title: Text('Noch niemand unterwegs')),
        for (final athlete in running) ListTile(leading: _Bib(bib: athlete.bib), title: Text(athlete.name.toUpperCase()), subtitle: Text('${athlete.category} · ${_lastStand(athlete)}'), trailing: const Text('läuft')),
      ])),
      _Section(title: 'Zuletzt im Ziel', subtitle: 'Laufzeit · Platz · Rückstand', child: Column(children: [
        if (finished.isEmpty) const ListTile(title: Text('Noch keine Zielzeit')),
        for (final athlete in finished) ListTile(leading: _Bib(bib: athlete.bib), title: Text(athlete.name.toUpperCase()), subtitle: Text(athlete.category), trailing: Text(_finishSummary(athlete))),
      ])),
    ]);
  }

  Widget _capturePage() {
    final event = _event;
    if (event == null) return const Center(child: Text('Kein Bewerb geladen'));
    return ListView(padding: const EdgeInsets.all(12), children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: OutlinedButton.icon(
          onPressed: _addSplitPointFromCapture,
          icon: const Icon(Icons.add_location_alt),
          label: const Text('Messpunkt hinzufügen'),
        ),
      ),
      for (final point in event.points)
        _Section(title: point.name, subtitle: point.type == PointType.finish ? 'Ziel · Prognose lernt nach ersten Durchgängen' : 'Messpunkt · Prognose lernt nach ersten Durchgängen', child: Column(children: [
          if (_candidatesFor(point).isEmpty) const ListTile(title: Text('Keine Athleten erwartet')),
          for (final c in _candidatesFor(point)) _CaptureRow(candidate: c, etaText: _eta(c.predictedTime), liveGapText: _liveGapText(c.athlete, point), onTap: () => _capture(c.athlete, point)),
        ])),
    ]);
  }

  Widget _resultsPage() {
    final event = _event;
    if (event == null) return const Center(child: Text('Kein Bewerb geladen'));
    return Column(children: [
      if (_viewingArchivedEvent) const ListTile(title: Text('Archivansicht'), subtitle: Text('Dieser Bewerb ist schreibgeschützt.')),
      SwitchListTile(title: const Text('Altersklassen getrennt anzeigen'), value: event.compareByCategory, onChanged: (v) => setState(() {
        event.compareByCategory = v;
        _compareByCategory = v;
      })),
      LayoutBuilder(builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        if (!desktop) {
          return Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: () => _exportDialog('CSV Export', _csvExport()), icon: const Icon(Icons.table_chart), label: const Text('CSV')),
            OutlinedButton.icon(onPressed: () => _exportDialog('HTML Export', _htmlExport()), icon: const Icon(Icons.html), label: const Text('HTML')),
            OutlinedButton.icon(onPressed: () => _exportDialog('CoachSplit Share', _shareText()), icon: const Icon(Icons.ios_share), label: const Text('Share')),
            OutlinedButton.icon(onPressed: _sharePngImage, icon: const Icon(Icons.image), label: const Text('Bild-Export')),
            if (!_viewingArchivedEvent) OutlinedButton.icon(onPressed: _archiveCurrentEvent, icon: const Icon(Icons.archive), label: const Text('Archivieren')),
          ]));
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text('Desktop-Export', style: Theme.of(context).textTheme.titleMedium),
                FilledButton.icon(onPressed: _downloadPngImage, icon: const Icon(Icons.image), label: const Text('PNG herunterladen')),
                OutlinedButton.icon(onPressed: _downloadCsvExport, icon: const Icon(Icons.table_chart), label: const Text('CSV herunterladen')),
                OutlinedButton.icon(onPressed: _downloadHtmlExport, icon: const Icon(Icons.html), label: const Text('HTML herunterladen')),
                OutlinedButton.icon(onPressed: _sharePngImage, icon: const Icon(Icons.ios_share), label: const Text('Teilen')),
                if (!_viewingArchivedEvent) OutlinedButton.icon(onPressed: _archiveCurrentEvent, icon: const Icon(Icons.archive), label: const Text('Archivieren')),
              ]),
            ),
          ),
        );
      }),
      const SizedBox(height: 8),
      Expanded(child: DefaultTabController(length: event.points.length, child: Column(children: [
        TabBar(isScrollable: true, tabs: [for (final p in event.points) Tab(text: p.name)]),
        Expanded(child: TabBarView(children: [for (final p in event.points) _Results(point: p, rows: _ranking(p), compareByCategory: event.compareByCategory, fmt: _fmtDuration)])),
      ]))),
    ]);
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.event});
  final RaceEvent? event;

  String _formatClock(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final athletes = event?.athletes ?? [];
    final waiting = athletes.where((a) => a.status == AthleteStatus.waiting).length;
    final running = athletes.where((a) => a.status == AthleteStatus.running).length;
    final finished = athletes.where((a) => a.status == AthleteStatus.finished).length;
    return Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 4), child: Row(children: [
      Expanded(child: _Stat(label: 'warten', value: '$waiting')),
      const SizedBox(width: 8),
      Expanded(child: _Stat(label: 'unterwegs', value: '$running')),
      const SizedBox(width: 8),
      Expanded(child: _Stat(label: 'fertig', value: '$finished')),
    ]));
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(children: [Text(value, style: Theme.of(context).textTheme.titleLarge), Text(label, style: Theme.of(context).textTheme.labelSmall)])));
}


class CoachSplitLogo extends StatelessWidget {
  const CoachSplitLogo({super.key, this.size = 34, this.showText = false});

  final double size;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF07121F),
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(color: const Color(0xFF2F8CFF), width: max(1.0, size * 0.055)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.timer_outlined, color: const Color(0xFF2F8CFF), size: size * 0.62),
          Positioned(
            bottom: size * 0.15,
            child: Text(
              'CS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.28,
                letterSpacing: -1,
              ),
            ),
          ),
        ],
      ),
    );

    if (!showText) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 10),
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
            children: [
              TextSpan(text: 'Coach'),
              TextSpan(text: 'Split', style: TextStyle(color: Color(0xFF2F8CFF))),
            ],
          ),
        ),
      ],
    );
  }
}

class _Nav extends StatelessWidget {
  const _Nav({required this.selected, required this.onChanged});
  final int selected;
  final ValueChanged<int> onChanged;

  String _formatClock(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final items = const [(Icons.settings, 'Setup'), (Icons.play_arrow, 'Start'), (Icons.touch_app, 'Erfassen'), (Icons.leaderboard, 'Ergebnis')];
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: SegmentedButton<int>(segments: [for (var i = 0; i < items.length; i++) ButtonSegment(value: i, icon: Icon(items[i].$1, size: 18), label: Text(items[i].$2))], selected: {selected}, onSelectionChanged: (s) => onChanged(s.first)));
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleMedium), Text(subtitle, style: Theme.of(context).textTheme.bodySmall), const Divider(), child])));
}

class _AthletePreview extends StatelessWidget {
  const _AthletePreview({required this.event, required this.onEditStart, required this.onRemove});
  final RaceEvent? event;
  final Future<void> Function(Athlete athlete) onEditStart;
  final void Function(Athlete athlete) onRemove;

  String _formatClock(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final athletes = event?.athletes ?? [];
    if (athletes.isEmpty) return const Text('Keine Athleten geladen');
    return Column(children: [for (final a in athletes) ListTile(dense: true, leading: _Bib(bib: a.bib), title: Text(a.name), subtitle: Text('${a.category} · Start ${_clock(a.scheduledStart)}'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(icon: const Icon(Icons.edit), onPressed: () => onEditStart(a)),
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => onRemove(a)),
          ]))]);
  }
  String _clock(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
}

class _StartRow extends StatelessWidget {
  const _StartRow({
    required this.athlete,
    required this.autoStartEnabled,
    required this.onStart,
  });

  final Athlete athlete;
  final bool autoStartEnabled;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final diff = athlete.scheduledStart.difference(DateTime.now());
    final late = diff.isNegative;

    return Card(
      child: ListTile(
        dense: true,
        leading: _Bib(bib: athlete.bib),
        title: Text(
          athlete.name.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(athlete.category),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (autoStartEnabled) ...[
              Text(
                late ? '+${_countdown(diff.abs())}' : _countdown(diff),
                style: TextStyle(
                  color: late ? Colors.redAccent : Colors.amberAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
            ],
            FilledButton(
              onPressed: onStart,
              child: const Text('START'),
            ),
          ],
        ),
      ),
    );
  }

  String _countdown(Duration d) {
    final totalSeconds = d.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _CaptureRow extends StatelessWidget {
  const _CaptureRow({
    required this.candidate,
    required this.etaText,
    required this.liveGapText,
    required this.onTap,
  });

  final Candidate candidate;
  final String etaText;
  final String liveGapText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasEta = candidate.predictedTime != null;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              _Bib(bib: candidate.athlete.bib, large: true),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.athlete.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${candidate.athlete.category}${candidate.athlete.isOwn ? ' · ★' : ''} · ${hasEta ? etaText : '—'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                liveGapText,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.point, required this.rows, required this.compareByCategory, required this.fmt});
  final SplitPoint point;
  final List<RankRow> rows;
  final bool compareByCategory;
  final String Function(Duration) fmt;

  String _formatClock(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const Center(child: Text('Noch keine Zeiten erfasst'));
    final groups = <String, List<RankRow>>{};
    for (final row in rows) {
      final key = compareByCategory ? row.athlete.category : 'ALLE';
      groups.putIfAbsent(key, () => []).add(row);
    }
    return ListView(padding: const EdgeInsets.all(12), children: [for (final entry in groups.entries) _Section(title: entry.key, subtitle: point.type == PointType.finish ? 'Zielwertung' : 'Gesamtzeit + letzter Abschnitt', child: Column(children: [for (final row in entry.value) ListTile(leading: _Bib(bib: row.athlete.bib), title: Text(row.athlete.name), subtitle: Text(point.type == PointType.finish ? '${row.athlete.category} · Zeit ${fmt(row.elapsed)}' : '${row.athlete.category} · Gesamt ${fmt(row.elapsed)} · Abschnitt ${row.sectionElapsed == null ? '—' : '${fmt(row.sectionElapsed!)} (${row.sectionPlace ?? row.place})'}'), trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text('Pl ${row.place}'), Text('+${fmt(row.deltaToLeader)}')]))]))]);
  }
}

class _Bib extends StatelessWidget {
  const _Bib({required this.bib, this.large = false});
  final int bib;
  final bool large;
  @override
  Widget build(BuildContext context) => CircleAvatar(radius: large ? 23 : 20, backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Text('$bib', style: TextStyle(fontWeight: FontWeight.w900, fontSize: large ? 18 : 15)));
}
