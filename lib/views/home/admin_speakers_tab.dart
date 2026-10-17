import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

const _brandColor = Color(0xFF0D5C4D);

class AdminSpeakersTab extends StatefulWidget {
  const AdminSpeakersTab({super.key});

  @override
  State<AdminSpeakersTab> createState() => _AdminSpeakersTabState();
}

class _AdminSpeakersTabState extends State<AdminSpeakersTab> {
  late Future<SpeakerList> _speakers;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _speakers = AuthService.getSpeakers();
  }

  Future<void> _refresh() async {
    final future = AuthService.getSpeakers();
    setState(() => _speakers = future);
    try {
      await future;
    } catch (_) {
      // El error se muestra en el FutureBuilder.
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openForm(int minCvWords, [SpeakerItem? speaker]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _SpeakerFormDialog(speaker: speaker, minCvWords: minCvWords),
    );
    if (saved != true || !mounted) return;
    _showMessage(
      speaker == null
          ? 'Conferencista guardado correctamente'
          : 'Conferencista actualizado correctamente',
    );
    await _refresh();
  }

  Future<void> _delete(SpeakerItem speaker) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar conferencista'),
        content: Text(
          '¿Eliminar a ${speaker.name}? Se borrarán su foto y su hoja de vida'
          '${speaker.activityCount > 0 ? ' y se quitará de ${speaker.activityCount} '
                    '${speaker.activityCount == 1 ? 'actividad' : 'actividades'}' : ''}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      await AuthService.deleteSpeaker(speaker.id);
      if (!mounted) return;
      _showMessage('Conferencista eliminado correctamente');
      await _refresh();
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Conferencistas',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Registra a cada conferencista con su foto, su nombre y su hoja '
            'de vida en Word o PDF.',
          ),
          const SizedBox(height: 12),
          FutureBuilder<SpeakerList>(
            future: _speakers,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text(
                  'No se pudieron cargar los conferencistas: '
                  '${snapshot.error.toString().replaceFirst('Exception: ', '')}',
                );
              }

              final data = snapshot.data!;
              final speakers = data.speakers;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: const Color(0xFFEDF6F2),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        'Recomendación: la hoja de vida debe tener como mínimo '
                        '${data.minCvWords} palabras (lo ideal es entre 150 y '
                        '250), en Word (.docx), e incluir '
                        'formación, trayectoria, áreas de '
                        'experiencia y logros. La foto puede ser JPG, PNG o '
                        'WEBP de hasta 5 MB, de preferencia cuadrada y de '
                        'frente.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _isDeleting
                        ? null
                        : () => _openForm(data.minCvWords),
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('Agregar conferencista'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    speakers.isEmpty
                        ? 'Conferencistas registrados'
                        : 'Conferencistas registrados (${speakers.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (speakers.isEmpty)
                    const Text('Aún no hay conferencistas registrados.'),
                  for (final speaker in speakers)
                    _SpeakerCard(
                      speaker: speaker,
                      minCvWords: data.minCvWords,
                      enabled: !_isDeleting,
                      onEdit: () => _openForm(data.minCvWords, speaker),
                      onDelete: () => _delete(speaker),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SpeakerCard extends StatelessWidget {
  final SpeakerItem speaker;
  final int minCvWords;
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SpeakerCard({
    required this.speaker,
    required this.minCvWords,
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final missing = [
      if (speaker.photoPath.isEmpty) 'foto',
      if (!speaker.hasCv) 'hoja de vida',
    ];
    final initial = speaker.name.isEmpty
        ? '?'
        : speaker.name.characters.first.toUpperCase();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: const Color(0xFFD5E7E0),
          foregroundImage: speaker.photoPath.isEmpty
              ? null
              : NetworkImage(speaker.photoUrl),
          onForegroundImageError: speaker.photoPath.isEmpty ? null : (_, _) {},
          child: Text(initial),
        ),
        title: Text(
          speaker.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            if (speaker.hasCv) 'Hoja de vida: ${speaker.cvWordCount} palabras',
            if (speaker.activityCount > 0)
              '${speaker.activityCount} '
                  '${speaker.activityCount == 1 ? 'actividad' : 'actividades'}',
            if (missing.isNotEmpty) 'Falta: ${missing.join(' y ')}',
          ].join('\n'),
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: enabled ? onEdit : null,
              tooltip: 'Actualizar conferencista',
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              onPressed: enabled ? onDelete : null,
              tooltip: 'Eliminar conferencista',
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeakerFormDialog extends StatefulWidget {
  final SpeakerItem? speaker;
  final int minCvWords;

  const _SpeakerFormDialog({required this.speaker, required this.minCvWords});

  @override
  State<_SpeakerFormDialog> createState() => _SpeakerFormDialogState();
}

class _SpeakerFormDialogState extends State<_SpeakerFormDialog> {
  late final TextEditingController _nameController;
  PlatformFile? _photo;
  Uint8List? _photoBytes;
  PlatformFile? _cv;
  bool _saving = false;
  String? _error;

  bool get _hasPhoto =>
      _photo != null || (widget.speaker?.photoPath.isNotEmpty ?? false);
  bool get _hasCv => _cv != null || (widget.speaker?.hasCv ?? false);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.speaker?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    if (result.isEmpty) return;

    final file = result.first;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _photo = file;
      _photoBytes = bytes;
      _error = null;
    });
  }

  Future<void> _pickCv() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx'],
    );
    if (result.isEmpty) return;

    setState(() {
      _cv = result.first;
      _error = null;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final validationError = name.length < 3
        ? 'Escribe el nombre completo del conferencista'
        : !_hasPhoto
        ? 'Selecciona la foto del conferencista'
        : !_hasCv
        ? 'Sube la hoja de vida en Word (.docx)'
        : null;
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AuthService.saveSpeaker(
        id: widget.speaker?.id,
        name: name,
        photo: _photo,
        cv: _cv,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Widget _buildPhotoPreview() {
    final speaker = widget.speaker;
    final ImageProvider? image = _photoBytes != null
        ? MemoryImage(_photoBytes!)
        : (speaker != null && speaker.photoPath.isNotEmpty)
        ? NetworkImage(speaker.photoUrl)
        : null;
    return CircleAvatar(
      radius: 36,
      backgroundColor: const Color(0xFFD5E7E0),
      foregroundImage: image,
      onForegroundImageError: image == null ? null : (_, _) {},
      child: const Icon(Icons.person_outline, size: 36, color: _brandColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.speaker != null;
    final cvLabel = _cv != null
        ? _cv!.name
        : (widget.speaker?.hasCv ?? false)
        ? '${widget.speaker!.cvFileName} '
              '(${widget.speaker!.cvWordCount} palabras)'
        : 'Ningún archivo seleccionado';

    return AlertDialog(
      title: Text(isEditing ? 'Editar conferencista' : 'Nuevo conferencista'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre del conferencista',
                  prefixIcon: Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildPhotoPreview(),
                  const SizedBox(width: 14),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _pickPhoto,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(_hasPhoto ? 'Cambiar foto' : 'Subir foto'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'JPG, PNG o WEBP, máximo 5 MB.',
                style: TextStyle(fontSize: 12, color: Color(0xFF586862)),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickCv,
                icon: const Icon(Icons.description_outlined),
                label: Text(
                  _hasCv ? 'Cambiar hoja de vida' : 'Subir hoja de vida',
                ),
              ),
              const SizedBox(height: 6),
              Text(cvLabel, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(
                'Word (.docx) con mínimo '
                '${widget.minCvWords} palabras.',
                style: const TextStyle(fontSize: 12, color: Color(0xFF586862)),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
