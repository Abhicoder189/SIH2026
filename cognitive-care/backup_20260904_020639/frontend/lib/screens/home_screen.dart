import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'attention_game_screen.dart';
import 'caregiver_dashboard_screen.dart';
import 'login_screen.dart';
import 'memory_game_screen.dart';
import 'notification_feed_screen.dart';
import 'pattern_game_screen.dart';
import 'preferences_screen.dart';
import 'progress_screen.dart';
import 'reminders_screen.dart';
import 'voice_assistant_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key,required this.userId,required this.role,required this.token});
  final String userId, role, token;
  @override State<HomeScreen> createState()=>_HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen>{
  Map<String,dynamic>? patient,summary,nextSession,feed;
  bool loading=true,syncing=false; String? error;
  @override void initState(){super.initState();_load();}
  Future<void> _load() async{
    if(widget.role=='caregiver'){if(mounted)setState(()=>loading=false);return;}
    try{
      final p=await ApiService.getMyPatient(widget.token); final id=p['patient_id'].toString();
      Map<String,dynamic>? s,f,n;
      try{s=await ApiService.getAnalyticsSummary(widget.token,id);}catch(_){ }
      try{n=await ApiService.getNextSession(widget.token,id);}catch(_){ }
      try{f=await ApiService.getNotificationFeed(widget.token,id);}catch(_){ }
      if(mounted)setState(()=>{patient=p,summary=s,nextSession=n,feed=f,loading=false,error=null});
    }catch(e){if(mounted)setState(()=>{loading=false,error=e.toString().replaceFirst('Exception: ','')});}
  }
  Future<void> _logout() async{try{await ApiService.logout(widget.token);}catch(_){ }await AuthService.logout();if(!mounted)return;Navigator.pushAndRemoveUntil(context,MaterialPageRoute(builder:(_)=>const LoginScreen()),(_)=>false);}
  void _open(Widget w)=>Navigator.push(context,MaterialPageRoute(builder:(_)=>w)).then((_){_load();});
  double _accuracy(String type){final byType=summary?['by_game_type'];if(byType is Map){final x=byType[type];if(x is Map){return ((x['accuracy']??x['average_accuracy']??0) as num).toDouble()/100;}}final avg=(summary?['average_accuracy'] as num?)?.toDouble()??0;return avg/100;}
  String _recommendation(){final r=nextSession?['recommendation'];if(r is Map)return '${r['game_type']??'activity'} • Difficulty ${r['difficulty']??1}';return r?.toString()??'Personalized activity';}
  @override Widget build(BuildContext context){
    if(widget.role=='caregiver')return Scaffold(appBar:AppBar(title:const Text('Cognitive Care'),actions:[IconButton(onPressed:_logout,icon:const Icon(Icons.logout))]),body:CaregiverDashboardScreen(token:widget.token));
    return Scaffold(backgroundColor:const Color(0xFFF7F8FC),appBar:AppBar(title:const Text('Cognitive Care'),actions:[if((feed?['items'] as List?)?.isNotEmpty??false)IconButton(onPressed:()=>_open(NotificationFeedScreen(token:widget.token,patientId:patient?['patient_id'].toString()??'')),icon:const Icon(Icons.notifications_active)),IconButton(onPressed:_logout,icon:const Icon(Icons.logout))]),body:loading?const Center(child:CircularProgressIndicator()):error!=null?_error():RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(20),children:[
      _welcome(),const SizedBox(height:18),_recommendation(),const SizedBox(height:18),
      _title('Cognitive Activities','Choose a gentle activity'),const SizedBox(height:12),
      _card('Memory Game','Recall familiar objects',Icons.psychology,()=>_open(MemoryGameScreen(patientId:patient!['patient_id'].toString(),token:widget.token))),
      _card('Attention Game','Find and count symbols',Icons.center_focus_strong,()=>_open(AttentionGameScreen(patientId:patient!['patient_id'].toString(),token:widget.token))),
      _card('Pattern Game','Complete simple sequences',Icons.extension,()=>_open(PatternGameScreen(patientId:patient!['patient_id'].toString(),token:widget.token))),
      const SizedBox(height:12),_title('Daily Support','Reminders, voice and accessibility'),const SizedBox(height:12),
      Row(children:[Expanded(child:_small('Reminders',Icons.notifications_active,()=>_open(RemindersScreen(token:widget.token,patientId:patient!['patient_id'].toString())))),const SizedBox(width:12),Expanded(child:_small('Voice Help',Icons.mic,()=>_open(VoiceAssistantScreen(token:widget.token))))]),
      const SizedBox(height:12),Row(children:[Expanded(child:_small('My Progress',Icons.insights,()=>_open(ProgressScreen(patientId:patient!['patient_id'].toString(),token:widget.token)))),const SizedBox(width:12),Expanded(child:_small('Settings',Icons.settings,()=>_open(PreferencesScreen(token:widget.token,patientId:patient!['patient_id'].toString(),language:patient!['language']?.toString()??'English'))))]),
      const SizedBox(height:20),_progress(),const SizedBox(height:20),const Text('Game performance is for personalization and engagement; it is not a medical diagnosis.',style:TextStyle(color:Colors.grey,fontSize:13))
    ]));
  }
  Widget _error()=>Center(child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.cloud_off,size:64),const SizedBox(height:16),Text(error!,textAlign:TextAlign.center,style:const TextStyle(fontSize:18)),const SizedBox(height:16),ElevatedButton(onPressed:(){setState(()=>loading=true);_load();},child:const Text('TRY AGAIN'))])));
  Widget _welcome(){final name=patient?['name']?.toString()??'Friend';return Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(borderRadius:BorderRadius.circular(24),gradient:const LinearGradient(colors:[Color(0xFF4B4FC7),Color(0xFF6D70D8)])),child:Row(children:[const CircleAvatar(radius:34,child:Icon(Icons.person,size:38)),const SizedBox(width:16),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Good day!',style:TextStyle(color:Colors.white70,fontSize:16)),Text(name,style:const TextStyle(color:Colors.white,fontSize:28,fontWeight:FontWeight.bold)),Text(patient?['language']?.toString()??'English',style:const TextStyle(color:Colors.white70,fontSize:15))]))]));}
  Widget _recommendation(){return Card(child:Padding(padding:const EdgeInsets.all(18),child:Row(children:[const Icon(Icons.auto_awesome,size:32),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Today\'s personalized activity',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold)),const SizedBox(height:5),Text(_recommendation(),style:const TextStyle(fontSize:19))])),const Icon(Icons.arrow_forward_ios,size:16)])));}
  Widget _title(String a,String b)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(a,style:const TextStyle(fontSize:23,fontWeight:FontWeight.bold)),const SizedBox(height:3),Text(b,style:TextStyle(fontSize:15,color:Colors.grey.shade700))]);
  Widget _card(String title,String sub,IconData icon,VoidCallback tap)=>Card(margin:const EdgeInsets.only(bottom:12),child:ListTile(contentPadding:const EdgeInsets.all(14),leading:CircleAvatar(radius:28,child:Icon(icon,size:30)),title:Text(title,style:const TextStyle(fontSize:21,fontWeight:FontWeight.bold)),subtitle:Text(sub,style:const TextStyle(fontSize:15)),trailing:const Icon(Icons.arrow_forward_ios),onTap:tap));
  Widget _small(String title,IconData icon,VoidCallback tap)=>Card(child:InkWell(onTap:tap,borderRadius:BorderRadius.circular(12),child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[Icon(icon,size:32),const SizedBox(height:8),Text(title,style:const TextStyle(fontSize:16,fontWeight:FontWeight.bold))]))));
  Widget _progress(){final vals=[['Memory',_accuracy('memory')],['Attention',_accuracy('attention')],['Pattern',_accuracy('pattern')]];return Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Your Progress',style:TextStyle(fontSize:21,fontWeight:FontWeight.bold)),const SizedBox(height:15),...vals.map((v){final x=(v[1] as double).clamp(0.0,1.0);return Padding(padding:const EdgeInsets.only(bottom:13),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(v[0] as String)),Text('${(x*100).round()}%')]),const SizedBox(height:5),LinearProgressIndicator(value:x,minHeight:8)]));})])));}
}
