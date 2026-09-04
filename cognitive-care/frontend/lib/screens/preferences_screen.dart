import 'package:flutter/material.dart';
import '../services/api_service.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key, required this.token, required this.patientId, required this.language});
  final String token, patientId, language;
  @override State<PreferencesScreen> createState() => _PreferencesScreenState();
}
class _PreferencesScreenState extends State<PreferencesScreen> {
  bool _largeText = true, _voice = true, _busy = false;
  String _language = 'English', _region = 'NER';
  final _languages = const ['English','Hindi','Assamese','Bengali','Manipuri','Khasi','Mizo','Naga'];
  @override void initState() { super.initState(); _language = widget.language.isEmpty ? 'English' : widget.language; _load(); }
  Future<void> _load() async { try { final p = await ApiService.getPreferences(widget.token, widget.patientId); if (!mounted) return; setState(() { _largeText = p['large_text'] != false; _voice = p['voice_enabled'] != false; _region = p['region']?.toString() ?? 'NER'; _language = p['language']?.toString() ?? _language; }); } catch (_) {} }
  Future<void> _save() async { setState(() => _busy = true); try { await ApiService.updatePreferences(widget.token, widget.patientId, {'language':_language,'region':_region,'large_text':_largeText,'voice_enabled':_voice}); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preferences saved'))); } catch(e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); } finally { if(mounted) setState(() => _busy=false); } }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Accessibility & Language')), body: ListView(padding: const EdgeInsets.all(24), children: [
    const Text('Language',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)), const SizedBox(height:10),
    DropdownButtonFormField<String>(initialValue:_languages.contains(_language)?_language:'English', items:_languages.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(), onChanged:(v)=>setState(()=>_language=v??'English'), decoration:const InputDecoration(border:OutlineInputBorder())),
    const SizedBox(height:28), const Text('Accessibility',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
    SwitchListTile(title:const Text('Large text',style:TextStyle(fontSize:19)),subtitle:const Text('Use larger text throughout the experience'),value:_largeText,onChanged:(v)=>setState(()=>_largeText=v)),
    SwitchListTile(title:const Text('Voice assistance',style:TextStyle(fontSize:19)),subtitle:const Text('Allow spoken responses from the assistant'),value:_voice,onChanged:(v)=>setState(()=>_voice=v)),
    const SizedBox(height:20), SizedBox(height:56,child:ElevatedButton(onPressed:_busy?null:_save,child:Text(_busy?'SAVING...':'SAVE PREFERENCES',style:const TextStyle(fontSize:18))))
  ]));
}
