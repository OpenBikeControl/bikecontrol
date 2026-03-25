import 'package:bike_control/services/blog_service.dart';
import 'package:bike_control/widgets/ui/colored_title.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class BlogPostsWidget extends StatefulWidget {
  final int maxPosts;
  final bool showHeader;
  final ValueChanged<bool>? onHasNewPosts;

  const BlogPostsWidget({super.key, this.maxPosts = 5, this.showHeader = true, this.onHasNewPosts});

  @override
  State<BlogPostsWidget> createState() => _BlogPostsWidgetState();
}

class _BlogPostsWidgetState extends State<BlogPostsWidget> {
  late Future<List<BlogPost>> _postsFuture;

  @override
  void initState() {
    super.initState();
    _postsFuture = BlogService().fetchPosts();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BlogPost>>(
      future: _postsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final posts = snapshot.data;
        if (posts == null || posts.isEmpty) return const SizedBox.shrink();

        final displayPosts = posts.take(widget.maxPosts).toList();
        final dateFormat = DateFormat.yMMMd();
        final hasNew = displayPosts.any((p) => p.isNew);

        // Notify parent about new-post status (used for tab badge).
        if (widget.onHasNewPosts != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onHasNewPosts!(hasNew);
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showHeader)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: ColoredTitle(text: 'BikeControl Blog', icon: Icons.rss_feed),
              ),
            if (widget.showHeader) const Gap(8),
            ...displayPosts.map(
              (post) => _BlogPostRow(post: post, dateFormat: dateFormat),
            ),
          ],
        );
      },
    );
  }
}

class _BlogPostRow extends StatelessWidget {
  final BlogPost post;
  final DateFormat dateFormat;

  const _BlogPostRow({required this.post, required this.dateFormat});

  @override
  Widget build(BuildContext context) {
    return Button.ghost(
      onPressed: () => launchUrl(Uri.parse(post.url)),
      child: SizedBox(
        width: double.infinity,
        child: Basic(
          leading: post.isNew ? _newBadge(context) : null,
          title: Text(
            post.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Theme.of(context).colorScheme.mutedForeground),
          ).normal,
          trailing: Row(
            spacing: 8,
            children: [
              Text(dateFormat.format(post.date)).xSmall.normal.muted,
              Icon(Icons.chevron_right_outlined, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _newBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: BKColor.main,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'NEW',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
