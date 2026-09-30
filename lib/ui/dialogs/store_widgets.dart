import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../config/game_config.dart';
import '../../logic/game_controller.dart';
import '../../model/item_ref.dart';
import '../game_scope.dart';
import '../painters/board_painters.dart';
import '../theme.dart';
import '../widgets/piece_view.dart';
import 'dialogs.dart';

/// Real-money part of the shop: special offers, the Dragon Club, gem packs
/// and bundles. Hidden entirely when the store can't be reached.
class StoreSection extends StatelessWidget {
  const StoreSection({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.game;
    final store = context.store;
    return ListenableBuilder(
      listenable: Listenable.merge([game, store]),
      builder: (context, _) {
        if (!game.storeConfig.enabled) return const SizedBox.shrink();
        final vip = game.storeConfig.products
            .where((p) => p.subscription)
            .firstOrNull;
        final showVip = vip != null && (game.vipActive || store.available);
        if (!store.available) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showVip) VipCard(product: vip),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Gem packs appear here when the store can be reached.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: Palette.inkSoft),
                ),
              ),
            ],
          );
        }
        bool sold(StoreProductDef p) => store.price(p.id) != null;
        final offers = game
            .productsIn('offer')
            .where((p) => !p.subscription && sold(p))
            .toList();
        final gems = game.productsIn('gems').where(sold).toList();
        final bundles = game.productsIn('bundles').where(sold).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final p in offers) _OfferCard(product: p),
            if (showVip) VipCard(product: vip),
            if (gems.isNotEmpty) ...[
              const _SectionTitle('Gems'),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: .7,
                children: [for (final p in gems) _GemPackCard(product: p)],
              ),
            ],
            if (bundles.isNotEmpty) ...[
              const _SectionTitle('Bundles'),
              for (final p in bundles) _OfferCard(product: p, compact: true),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: store.restore,
                  child: const Text(
                    'Restore purchases',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
            Text(
              'Payments go through ${_storeName()}. Everything in the game '
              'can also be earned by playing.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Palette.inkSoft),
            ),
            const SizedBox(height: 4),
            const _SectionTitle('Spend gems'),
          ],
        );
      },
    );
  }

  static String _storeName() {
    if (kIsWeb) return 'the store';
    return Platform.isIOS ? 'the App Store' : 'Google Play';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 10, 2, 6),
    child: Row(
      children: [
        Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider(thickness: 1.5)),
      ],
    ),
  );
}

/// The picture for a product: an item, energy, a gem pile, a ticket or a
/// crown.
class ProductIcon extends StatelessWidget {
  const ProductIcon(this.icon, {super.key, this.size = 52});

  final String icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (icon == 'energy') {
      return CurrencyIcon(CurrencyKind.energy, size: size * .9);
    }
    if (icon == 'vip') {
      return Icon(
        Icons.workspace_premium_rounded,
        size: size,
        color: const Color(0xFFE0A21A),
      );
    }
    if (icon == 'pass') {
      return Icon(
        Icons.confirmation_number_rounded,
        size: size,
        color: const Color(0xFFE0A21A),
      );
    }
    if (icon.startsWith('gems:')) {
      return _GemPile(int.tryParse(icon.substring(5)) ?? 1, size: size);
    }
    return ItemIcon(ItemRef.parse(icon), size: size);
  }
}

/// 1 to 5 gems heaped together; bigger packs get bigger heaps.
class _GemPile extends StatelessWidget {
  const _GemPile(this.tier, {required this.size});

  final int tier;
  final double size;

  @override
  Widget build(BuildContext context) {
    const spots = [
      (0.0, -.04, 1.0),
      (-.24, .1, .8),
      (.24, .1, .8),
      (-.1, .16, .72),
      (.16, -.14, .66),
    ];
    final n = tier.clamp(1, spots.length);
    final g = size * .64;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = n - 1; i >= 0; i--)
            Transform.translate(
              offset: Offset(spots[i].$1 * size, spots[i].$2 * size),
              child: CurrencyIcon(CurrencyKind.gem, size: g * spots[i].$3),
            ),
        ],
      ),
    );
  }
}

/// Buy button showing the store's price in the player's currency.
class PriceButton extends StatelessWidget {
  const PriceButton({super.key, required this.product, this.compact = false});

  final StoreProductDef product;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final waiting = store.pending(product.id);
        final price = store.price(product.id) ?? product.priceHint;
        return GameButton(
          color: waiting ? const Color(0xFFBDB3CC) : Palette.green,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: 6,
          ),
          onTap: waiting ? () {} : () => store.buy(product.id),
          child: Text(
            waiting ? 'Pending...' : price,
            maxLines: 1,
            style: TextStyle(fontSize: compact ? 13 : 15),
          ),
        );
      },
    );
  }
}

class _GemPackCard extends StatelessWidget {
  const _GemPackCard({required this.product});

  final StoreProductDef product;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: product.badge.isEmpty
              ? const Color(0xFFF1D9E6)
              : const Color(0xFFFFC94D),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 14,
            child: product.badge.isEmpty
                ? null
                : Text(
                    product.badge,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB8860B),
                    ),
                  ),
          ),
          Expanded(
            child: FittedBox(child: ProductIcon(product.icon, size: 50)),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CurrencyIcon(CurrencyKind.gem, size: 15),
              Text(
                ' ${product.gems}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          PriceButton(product: product, compact: true),
        ],
      ),
    );
  }
}

/// A wide card: starter pack, bundles.
class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.product, this.compact = false});

  final StoreProductDef product;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final config = context.game.config;
    final highlight = !compact;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: highlight
            ? const LinearGradient(
                colors: [Color(0xFFFFF4D6), Color(0xFFFFE0EE)],
              )
            : null,
        color: highlight ? null : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight ? const Color(0xFFFFC94D) : const Color(0xFFF1D9E6),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          ProductIcon(product.icon, size: compact ? 46 : 58),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (product.badge.isNotEmpty) _Badge(product.badge),
                Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                  ),
                ),
                if (!compact)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final r in product.rewards)
                          SizedBox.square(
                            dimension: 28,
                            child: lootIcon(r, config: config),
                          ),
                      ],
                    ),
                  ),
                if (product.desc.isNotEmpty)
                  Text(product.desc, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          PriceButton(product: product, compact: compact),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: Palette.pink,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// Dragon Club: the offer, or the perks and the daily gems while active.
class VipCard extends StatelessWidget {
  const VipCard({super.key, required this.product});

  final StoreProductDef product;

  @override
  Widget build(BuildContext context) {
    final game = context.game;
    final vip = game.storeConfig.vip;
    final active = game.vipActive;
    final ends = game.vipEnds;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5B4B8A), Color(0xFF8E6CD8)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFC94D), width: 2),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: Row(
          children: [
            const ProductIcon('vip', size: 50),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    active ? '${product.name} (active)' : product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15.5,
                    ),
                  ),
                  Text(
                    '${vip.dailyGems} gems every day, +${vip.energyMax} max '
                    'energy, +${vip.offlineHours.toStringAsFixed(0)}h hoard.',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (active)
                    Text(
                      'Until ${ends.day}/${ends.month}/${ends.year}. '
                      'Renews unless cancelled in your store account.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    )
                  else
                    const Text(
                      'Monthly, renews automatically. Cancel anytime in your '
                      'store account.',
                      style: TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            if (!active)
              PriceButton(product: product, compact: true)
            else if (game.vipGemsReady)
              GameButton(
                color: Palette.pink,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                onTap: game.claimVipGems,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CurrencyIcon(CurrencyKind.gem, size: 16),
                    Text(
                      ' ${vip.dailyGems}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              )
            else
              const Icon(Icons.check_circle_rounded, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}

/// Buys this festival's premium track with money, next to the gem button.
class FestivalPassButton extends StatelessWidget {
  const FestivalPassButton({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.game;
    final store = context.store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final pass = game.productsIn('festival').firstOrNull;
        if (pass == null || store.price(pass.id) == null) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: PriceButton(product: pass, compact: true),
        );
      },
    );
  }
}

/// Thanks the player and shows what a purchase gave.
Future<void> showPurchaseThanks(
  BuildContext context,
  StoreProductDef product,
  List<LootEntry> rewards,
) {
  final game = context.game;
  if (rewards.isNotEmpty) {
    return showChestRewards(context, 'Thank you!', rewards);
  }
  final message = product.festivalPass
      ? 'The premium reward track is unlocked. Enjoy the festival!'
      : product.vipDays > 0
      ? 'Welcome to the ${product.name}! Collect your daily gems in the shop.'
      : 'Your purchase is complete.';
  return showDialog(
    context: context,
    builder: (ctx) => GameDialog(
      celebrate: true,
      title: 'Thank you!',
      titleColor: const Color(0xFFE0A21A),
      actions: [
        GameButton(
          onTap: () => Navigator.pop(ctx),
          child: const Text('Awesome!'),
        ),
      ],
      child: Column(
        children: [
          ProductIcon(product.icon, size: 64),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          if (product.vipDays > 0 && game.vipGemsReady) ...[
            const SizedBox(height: 8),
            GameButton(
              color: Palette.pink,
              onTap: () {
                game.claimVipGems();
                Navigator.pop(ctx);
              },
              child: Text('Collect ${game.storeConfig.vip.dailyGems} gems'),
            ),
          ],
        ],
      ),
    ),
  );
}
