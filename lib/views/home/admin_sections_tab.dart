import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

class AdminSectionsTab extends StatefulWidget {
  const AdminSectionsTab({super.key});

  @override
  State<AdminSectionsTab> createState() => _AdminSectionsTabState();
}

class _AdminSectionsTabState extends State<AdminSectionsTab> {
  late Future<List<ContentSection>> _sections;
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _videoUrl = TextEditingController();
  PlatformFile? _image;
  PlatformFile? _video;
  bool _saving = false;
  int? _movingSectionId;

  @override
  void initState() {
    super.initState();
    _sections = AuthService.getContentSections();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _videoUrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    if (result.isNotEmpty) {
      setState(() => _image = result.first);
    }
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp4', 'mov', 'webm', 'avi', 'mkv'],
    );
    if (result.isNotEmpty) {
      setState(() => _video = result.first);
    }
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    setState(() => _saving = true);
    try {
      await AuthService.saveContentSection(
        title: title,
        body: body,
        videoUrl: _videoUrl.text.trim(),
        image: _image,
        video: _video,
      );
      _title.clear();
      _body.clear();
      _videoUrl.clear();
      if (mounted) {
        final sections = AuthService.getContentSections();
        setState(() {
          _image = null;
          _video = null;
          _sections = sections;
        });
        _message('Sección creada correctamente.');
      }
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _edit(ContentSection section) async {
    final titleController = TextEditingController(text: section.title);
    final bodyController = TextEditingController(text: section.body);
    final videoUrlController = TextEditingController(text: section.videoUrl);
    PlatformFile? image;
    PlatformFile? video;
    var removeImage = false;
    var removeVideo = false;
    var saving = false;

    Future<void> pickImage(void Function(void Function()) update) async {
      final result = await FilePicker.pickFiles(type: FileType.image);
      if (result.isNotEmpty) {
        update(() {
          image = result.first;
          removeImage = false;
        });
      }
    }

    Future<void> pickVideo(void Function(void Function()) update) async {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mov', 'webm', 'avi', 'mkv'],
      );
      if (result.isNotEmpty) {
        update(() {
          video = result.first;
          removeVideo = false;
        });
      }
    }

    try {
      final updated = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: const Text('Actualizar sección'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Título'),
                  ),
                  TextField(
                    controller: bodyController,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(labelText: 'Texto'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: saving ? null : () => pickImage(update),
                    icon: const Icon(Icons.image_outlined),
                    label: Text(image?.name ?? 'Reemplazar imagen'),
                  ),
                  if (section.imagePath.isNotEmpty || image != null)
                    TextButton.icon(
                      onPressed: saving
                          ? null
                          : () => update(() {
                              image = null;
                              removeImage = true;
                            }),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Quitar imagen'),
                    ),
                  OutlinedButton.icon(
                    onPressed: saving ? null : () => pickVideo(update),
                    icon: const Icon(Icons.video_file_outlined),
                    label: Text(video?.name ?? 'Reemplazar video'),
                  ),
                  if (section.videoPath.isNotEmpty ||
                      section.videoUrl.isNotEmpty ||
                      video != null)
                    TextButton.icon(
                      onPressed: saving
                          ? null
                          : () => update(() {
                              video = null;
                              removeVideo = true;
                              videoUrlController.clear();
                            }),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Quitar video'),
                    ),
                  TextField(
                    controller: videoUrlController,
                    decoration: const InputDecoration(
                      labelText: 'URL del video',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        update(() => saving = true);
                        try {
                          await AuthService.updateContentSection(
                            id: section.id,
                            title: titleController.text.trim(),
                            body: bodyController.text.trim(),
                            videoUrl: videoUrlController.text.trim(),
                            image: image,
                            video: video,
                            removeImage: removeImage,
                            removeVideo: removeVideo,
                          );
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(true);
                          }
                        } catch (error) {
                          if (dialogContext.mounted) {
                            _message(
                              error.toString().replaceFirst('Exception: ', ''),
                            );
                            update(() => saving = false);
                          }
                        }
                      },
                child: const Text('Guardar cambios'),
              ),
            ],
          ),
        ),
      );
      if (updated == true && mounted) {
        final sections = AuthService.getContentSections();
        setState(() => _sections = sections);
        _message('Sección actualizada correctamente.');
      }
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      titleController.dispose();
      bodyController.dispose();
      videoUrlController.dispose();
    }
  }

  void _message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
    }
  }

  Future<void> _refreshSections() async {
    final sections = AuthService.getContentSections();
    if (!mounted) return;
    setState(() {
      _sections = sections;
    });
    await sections;
  }

  Future<void> _delete(ContentSection section) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar sección'),
        content: Text('¿Eliminar "${section.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await AuthService.deleteContentSection(section.id);
      final sections = AuthService.getContentSections();
      if (mounted) {
        setState(() {
          _sections = sections;
        });
      }
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _move(ContentSection section, bool up) async {
    if (_movingSectionId != null) return;
    setState(() => _movingSectionId = section.id);
    try {
      await AuthService.moveContentSection(section.id, up: up);
      final sections = AuthService.getContentSections();
      if (mounted) setState(() => _sections = sections);
      await sections;
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _movingSectionId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshSections,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Crear sección para Inicio',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Título',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Texto',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _saving ? null : _pickImage,
            icon: const Icon(Icons.image_outlined),
            label: Text(_image?.name ?? 'Agregar imagen'),
          ),
          OutlinedButton.icon(
            onPressed: _saving ? null : _pickVideo,
            icon: const Icon(Icons.video_file_outlined),
            label: Text(_video?.name ?? 'Subir video'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _videoUrl,
            decoration: const InputDecoration(
              labelText: 'URL del video (opcional)',
              hintText: 'https://...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Guardando...' : 'Crear sección'),
          ),
          const SizedBox(height: 24),
          Text(
            'Secciones publicadas',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<ContentSection>>(
            future: _sections,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text(
                  'No se pudieron cargar las secciones: ${snapshot.error}',
                );
              }
              final sections = snapshot.data ?? const <ContentSection>[];
              if (sections.isEmpty) {
                return const Text('Todavía no hay secciones.');
              }
              return Column(
                children: [
                  for (var index = 0; index < sections.length; index++)
                    Builder(
                      builder: (context) {
                        final section = sections[index];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  section.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                if (section.body.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      section.body,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Wrap(
                                    spacing: 2,
                                    children: [
                                      IconButton(
                                        onPressed: _movingSectionId != null
                                            ? null
                                            : () => _edit(section),
                                        icon: const Icon(Icons.edit_outlined),
                                        tooltip: 'Actualizar sección',
                                      ),
                                      IconButton(
                                        onPressed:
                                            index == 0 ||
                                                _movingSectionId != null
                                            ? null
                                            : () => _move(section, true),
                                        icon: const Icon(Icons.arrow_upward),
                                        tooltip: 'Subir sección',
                                      ),
                                      IconButton(
                                        onPressed:
                                            index == sections.length - 1 ||
                                                _movingSectionId != null
                                            ? null
                                            : () => _move(section, false),
                                        icon: const Icon(Icons.arrow_downward),
                                        tooltip: 'Bajar sección',
                                      ),
                                      IconButton(
                                        onPressed: _movingSectionId != null
                                            ? null
                                            : () => _delete(section),
                                        icon: const Icon(Icons.delete_outline),
                                        tooltip: 'Eliminar sección',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
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
