//Thư viện
import 'package:flutter/material.dart';
//Class xử lý
import 'account_logic.dart';
import '../../services/model.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({Key? key}) : super(key: key);
  @override
  _AccountScreenState createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final AccountScreenLogic logic = AccountScreenLogic();

  @override
  void initState() {
    super.initState();
    logic.init(context, () => setState(() {}));
  }

  @override
  void dispose() {
    logic.dispose();
    super.dispose();
  }

  Widget _buildBody() {
    if (logic.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (logic.currentUser == null) {
      return Center(
        child: ElevatedButton(
          onPressed: logic.handleSignIn,
          child: const Text("Đăng nhập với Google"),
        ),
      );
    }

    if (logic.user == null) {
      return const Center(child: Text('Đang tải thông tin...'));
    }

    return RefreshIndicator(
      onRefresh: logic.refreshUserData,
      child: _buildUserContent(),
    );
  }

  Widget _buildUserContent() {
    return Column(
      children: [
        UserAccountsDrawerHeader(
          accountName: Text(logic.user!.displayName),
          accountEmail: Text(logic.user!.email),
          currentAccountPicture:
              logic.user!.photoURL != null && logic.user!.photoURL!.isNotEmpty
                  ? CircleAvatar(
                      backgroundImage: NetworkImage(logic.user!.photoURL!),
                    )
                  : CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Text(
                        logic.user!.displayName.isNotEmpty
                            ? logic.user!.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                        ),
                      ),
                    ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(8.0),
            children: [
              logic.buildMangaList<String>(
                'Truyện Theo Dõi',
                logic.user!.following,
                logic.buildFollowingItem,
              ),
              const SizedBox(height: 16),
              logic.buildMangaList<ReadingProgress>(
                'Lịch Sử Đọc Truyện',
                logic.user!.readingProgress,
                logic.buildReadingItem,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: logic.handleSignOut,
                  child: const Text("Đăng xuất"),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài khoản của bạn'),
      ),
      body: _buildBody(),
    );
  }
}
