import 'package:baakhapaa/helpers/helpers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/header.dart';

class ContactUsScreen extends StatelessWidget {
  static const routeName = '/contact-us-screen';

  const ContactUsScreen({Key? key}) : super(key: key);
  void launchMessengerApp() async {
    final url = Uri.parse("http://m.me/baakhapaa");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  void launchViberGroup() async {
    final url = Uri.parse(
        "https://invite.viber.com/?g2=AQAzrYc1KMHhlFKN9OqY7V7avoAVmTPADgp3vPAFoTJ1vSStiuoW1ujAqD8yBfn%2F");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  void launchFacebookApp() async {
    final url = Uri.parse("https://www.facebook.com/baakhapaa");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  void launchYoutubeApp() async {
    final url = Uri.parse("https://www.youtube.com/@baakhapaa");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  void launchInstaApp() async {
    final url = Uri.parse("https://www.instagram.com/_u/baakhapaa_app/");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Color.fromARGB(255, 9, 9, 9)
          : Colors.white,
      appBar: header(context: context, titleText: context.l10n.contactUs),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).brightness == Brightness.dark
                    ? Color.fromARGB(255, 9, 9, 9)
                    : Colors.white,
                Theme.of(context).brightness == Brightness.dark
                    ? Color(0xFF082032)
                    : Color.fromARGB(255, 188, 186, 186),
              ],
            ),
          ),
          child: Column(
            children: [
              // Header section with logo
              _buildHeaderSection(context),

              // About section
              _buildAboutSection(context),

              // Social media section
              _buildSocialMediaSection(context),

              SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).brightness == Brightness.dark
                ? Color(0xFF2A2A2A)
                : Colors.white,
            Theme.of(context).brightness == Brightness.dark
                ? Color(0xFF1E1E1E)
                : Colors.grey.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo with modern styling - optimized for horizontal golden logo
          Container(
            height: 80,
            width: double.infinity,
            constraints: BoxConstraints(maxWidth: 280),
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).brightness == Brightness.dark
                      ? Color(0xFF1A1A1A)
                      : Colors.grey.shade50,
                  Theme.of(context).brightness == Brightness.dark
                      ? Color(0xFF0D1B2A)
                      : Colors.white,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: Colors.amber.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: 'https://baakhapaa.com/assets/img/logo/logo3.png',
                fit: BoxFit.contain,
                alignment: Alignment.center,
                placeholder: (context, url) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.grey.shade200,
                        Colors.grey.shade100,
                      ],
                    ),
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.amber.shade600),
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade100, Colors.amber.shade50],
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.business,
                          color: Colors.amber.shade700,
                          size: 32,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'BAAKHAPAA',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade800,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 20),

          Text(
            context.l10n.storiesArePowerStoriesAreRewards,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.blue.shade300
                  : Colors.blue.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12),

          // Download counter with modern badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade400, Colors.green.shade600],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '17,000+ DOWNLOADS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return Column(
      children: [
        // App Overview Card
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).brightness == Brightness.dark
                    ? Color(0xFF2A2A2A)
                    : Colors.white,
                Theme.of(context).brightness == Brightness.dark
                    ? Color(0xFF1E1E1E)
                    : Colors.grey.shade50,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.15),
                blurRadius: 12,
                spreadRadius: 2,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.purple.shade400,
                          Colors.purple.shade600
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.apps_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.baakhapa,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Color(0xFF082032),
                          ),
                        ),
                        Text(
                          context.l10n.companyMissionStatement,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),

              Text(
                // 'A multi-purpose content sharing app that monetizes engagement according to the knowledge of storytelling.',
                context.l10n.companyMissionStatement,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.9)
                      : Color(0xFF2D3748),
                ),
              ),
              SizedBox(height: 20),

              // Features Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildFeatureBadge(context.l10n.play, Colors.blue),
                  _buildFeatureBadge(context.l10n.learn, Colors.green),
                  _buildFeatureBadge(context.l10n.earn, Colors.orange),
                ],
              ),
              SizedBox(height: 20),

              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Color(0xFF1A1A1A)
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.monetization_on_rounded,
                      color: Colors.blue.shade600,
                      size: 32,
                    ),
                    SizedBox(height: 8),
                    Text(
                      context.l10n.monetizeYourSCREENTIME,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      context.l10n.learnDescription,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Company Info Card
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Color(0xFF2A2A2A)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade600],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.info_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    context.l10n.aboutOurCompany,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Color(0xFF082032),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                // 'Baakhapaa IT and Marketing Solutions LLC is a software development and marketing company that strives to create stories of success for its clients. We focus on providing informative multimedia platforms for organizations that strive to be a successful brand and propel the business to new heights.',
                context.l10n.companyDescription1,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  fontWeight: FontWeight.w400,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.85)
                      : Color(0xFF4A5568),
                ),
              ),
              SizedBox(height: 16),
              Text(
                // 'With our services, organizations can create a brand that works on uniting people, promoting culture, and moving towards spiritual consciousness through the power of storytelling.',
                context.l10n.companyDescription2,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  fontWeight: FontWeight.w400,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.85)
                      : Color(0xFF4A5568),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureBadge(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildSocialMediaSection(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Color(0xFF2A2A2A)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade400, Colors.purple.shade600],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.connect_without_contact,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Text(
                context.l10n.getInTouch,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Social media buttons grid
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              _buildSocialButton(
                context,
                context.l10n.instagram,
                FontAwesome5.instagram,
                Color(0xFFE4405F),
                launchInstaApp,
              ),
              _buildSocialButton(
                context,
                context.l10n.facebook,
                Icons.facebook,
                Color(0xFF1877F2),
                launchFacebookApp,
              ),
              _buildSocialButton(
                context,
                context.l10n.youTube,
                FontAwesome5.youtube,
                Color(0xFFFF0000),
                launchYoutubeApp,
              ),
              _buildSocialButton(
                context,
                context.l10n.message,
                FontAwesome5.facebook_messenger,
                Color(0xFF0084FF),
                launchMessengerApp,
              ),
              _buildSocialButton(
                context,
                context.l10n.viber,
                FontAwesome5.viber,
                Color(0xFF665CAC),
                launchViberGroup,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton(BuildContext context, String name, IconData icon,
      Color color, VoidCallback onPressed) {
    return Container(
      width: 100,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onPressed,
                child: Center(
                  child: Icon(
                    icon,
                    color: color,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 8),
          Text(
            name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
