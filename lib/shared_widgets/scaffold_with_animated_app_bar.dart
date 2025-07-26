import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class ScaffoldWithAnimatedAppBar extends StatefulWidget {
  final String title;
  final Widget Function(ScrollController controller) bodyBuilder;
  final List<Widget>? actions;

  const ScaffoldWithAnimatedAppBar({
    Key? key,
    required this.title,
    required this.bodyBuilder,
    this.actions,
  }) : super(key: key);

  @override
  _ScaffoldWithAnimatedAppBarState createState() =>
      _ScaffoldWithAnimatedAppBarState();
}

class _ScaffoldWithAnimatedAppBarState
    extends State<ScaffoldWithAnimatedAppBar> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTopButton = false;
  bool _isAppBarVisible = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!mounted) return;

    if (_scrollController.offset >= 400 && !_showScrollToTopButton) {
      setState(() => _showScrollToTopButton = true);
    } else if (_scrollController.offset < 400 && _showScrollToTopButton) {
      setState(() => _showScrollToTopButton = false);
    }

    final scrollDirection = _scrollController.position.userScrollDirection;
    if (scrollDirection == ScrollDirection.reverse && _isAppBarVisible) {
      setState(() => _isAppBarVisible = false);
    } else if (scrollDirection == ScrollDirection.forward &&
        !_isAppBarVisible) {
      setState(() => _isAppBarVisible = true);
    }
  }

  void _scrollToTop() {
    setState(() => _isAppBarVisible = true);
    _scrollController.animateTo(
      0,
      duration: Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double appBarHeight = kToolbarHeight;

    return Scaffold(
      body: Stack(
        children: [
          AnimatedPadding(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: EdgeInsets.only(
                top: _isAppBarVisible
                    ? appBarHeight + statusBarHeight
                    : statusBarHeight),
            child: widget.bodyBuilder(_scrollController),
          ),
          AnimatedPositioned(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: _isAppBarVisible ? 0 : -(appBarHeight + statusBarHeight),
            left: 0,
            right: 0,
            child: Container(
              color: Theme.of(context).appBarTheme.backgroundColor ??
                  Theme.of(context).primaryColor,
              child: AppBar(
                title: Text(widget.title),
                elevation: 0,
                actions: widget.actions,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _showScrollToTopButton
          ? FloatingActionButton(
              mini: true,
              onPressed: _scrollToTop,
              child: Icon(Icons.arrow_upward),
            )
          : null,
    );
  }
}
