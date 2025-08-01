import 'package:flutter/material.dart';

import '../screens/home_screen.dart';
import '../screens/friends_screen.dart';
import '../screens/group_invites_screen.dart';

class HomeDrawer extends StatelessWidget {
  final String nickname;
  final String email;
  final String? photoUrl;
  final HomeTab selectedTab;
  final void Function(HomeTab) onTabSelected;

  const HomeDrawer({
    Key? key,
    required this.nickname,
    required this.email,
    required this.photoUrl,
    required this.selectedTab,
    required this.onTabSelected,
  }) : super(key: key);

  void _handleTabTap(BuildContext context, HomeTab tab) {
    if (tab == HomeTab.friends) {
      Navigator.pop(context);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => FriendsScreen()),
      );
      return;
    }
    if (tab == HomeTab.groupInvites) {
      Navigator.pop(context);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => GroupInvitesScreen()),
      );
      return;
    }
    Navigator.pop(context);
    Navigator.pushReplacementNamed(
      context,
      '/home',
      arguments: tab,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(nickname),
            accountEmail: Text(email),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.deepPurple,
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
              child: photoUrl == null ? Icon(Icons.person, size: 40, color: Colors.white) : null,
            ),
            decoration: BoxDecoration(
              color: Colors.deepPurple,
            ),
          ),
          ListTile(
            leading: Icon(Icons.groups),
            title: Text('Gruplar'),
            selected: selectedTab == HomeTab.groups,
            onTap: () => _handleTabTap(context, HomeTab.groups),
          ),
          ListTile(
            leading: Icon(Icons.chat_bubble_outline),
            title: Text('DM\'ler'),
            selected: selectedTab == HomeTab.dms,
            onTap: () => _handleTabTap(context, HomeTab.dms),
          ),
          ListTile(
            leading: Icon(Icons.people_alt),
            title: Text('Arkadaşlar'),
            selected: selectedTab == HomeTab.friends,
            onTap: () => _handleTabTap(context, HomeTab.friends),
          ),
          ListTile(
            leading: Icon(Icons.mail_outline),
            title: Text('Grup Davetleri'),
            selected: selectedTab == HomeTab.groupInvites,
            onTap: () => _handleTabTap(context, HomeTab.groupInvites),
          ),
        ],
      ),
    );
  }
} 