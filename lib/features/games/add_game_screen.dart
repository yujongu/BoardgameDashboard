import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/models/dashboard_state.dart';
import '../../shared/models/game.dart';
import '../../shared/theme/app_theme.dart';

class AddGameScreen extends StatelessWidget {
  final DashboardState state;

  const AddGameScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final available = state.availableToAdd;

    return Scaffold(
      backgroundColor: kColorBackground,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0905),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kColorPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'ADD TO COLLECTION',
          style: GoogleFonts.newsreader(
            color: kColorPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            letterSpacing: 3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: kColorAmberBorder),
        ),
      ),
      body: available.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    color: kColorPrimary,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'All relics recovered',
                    style: GoogleFonts.newsreader(
                      color: kColorOnSurfaceVariant,
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text(
                    '${available.length} relics awaiting recovery',
                    style: GoogleFonts.spaceGrotesk(
                      color: kColorOutline,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: available.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, i) =>
                        _GameTile(game: available[i], state: state),
                  ),
                ),
              ],
            ),
    );
  }
}

class _GameTile extends StatelessWidget {
  final Game game;
  final DashboardState state;

  const _GameTile({required this.game, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kColorSurfaceHigh,
        border: Border.all(color: kColorAmberBorder),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          game.name,
          style: GoogleFonts.newsreader(
            color: kColorOnSurface,
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            game.category.toUpperCase(),
            style: GoogleFonts.spaceGrotesk(
              color: kColorOutline,
              fontSize: 10,
              letterSpacing: 1.2,
            ),
          ),
        ),
        trailing: GestureDetector(
          onTap: () {
            state.addGame(game);
            Navigator.of(context).pop();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(color: kColorPrimary),
            child: Text(
              'ADD',
              style: GoogleFonts.spaceGrotesk(
                color: kColorOnPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
