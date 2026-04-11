import 'dart:io';

import 'package:baakhapaa/models/url.dart';
import 'package:baakhapaa/screens/user/user_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../utils/puppet_screen_mapping.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';

import '../../widgets/header.dart';
import '../../helpers/helpers.dart';
import '../../providers/auth.dart';
import '../../screens/shop/single_product_screen.dart';
import '../../widgets/app_button.dart';
import '../../widgets/loading.dart';

class MlbbRegistrationScreen extends StatefulWidget {
  static const routeName = '/mlbb-registration-screen';
  const MlbbRegistrationScreen({Key? key}) : super(key: key);

  @override
  State<MlbbRegistrationScreen> createState() => _MlbbRegistrationScreenState();
}

class _MlbbRegistrationScreenState extends State<MlbbRegistrationScreen>
    with PuppetInteractionMixin {
  var _isInit = true;
  var _mlbbTicketPurchased = false;
  var _isLoading = true;
  final Uri _url = Uri.parse('https://discord.gg/PTbhcg6N');
  final String phoneNumber = '9808335630';
  final _formKey = GlobalKey<FormState>();
  TextEditingController _nameController = TextEditingController();
  TextEditingController _contactNumberController = TextEditingController();
  TextEditingController _ignNumberController = TextEditingController();
  TextEditingController _idNumberController = TextEditingController();
  TextEditingController _discordIdController = TextEditingController();
  TextEditingController _numberOfPlayersController = TextEditingController();
  TextEditingController _teamPlayersController = TextEditingController();
  TextEditingController _gameIdController = TextEditingController();
  TextEditingController _serverIdController = TextEditingController();
  TextEditingController _teamLogoController = TextEditingController();
  late XFile _pickedImage;
  List<Map<String, dynamic>> _teamMembersList = [];

  @override
  void didChangeDependencies() {
    if (_isInit) {
      var auth = Provider.of<Auth>(context, listen: false);
      auth.checkMlbbTicketPurchased().then((_) {
        setState(() {
          _mlbbTicketPurchased = auth.mlbbTicketPurchased;
          _isLoading = false;
        });
      });
      _isInit = false;
    }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    super.dispose();
    _nameController.dispose();
    _contactNumberController.dispose();
    _ignNumberController.dispose();
    _idNumberController.dispose();
    _discordIdController.dispose();
    _numberOfPlayersController.dispose();
    _teamPlayersController.dispose();
    _gameIdController.dispose();
    _serverIdController.dispose();
    _teamLogoController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const boldTextStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
    );

    const textStyle = TextStyle(
      fontSize: 16,
    );

    Future<void> _launchDiscordUrl() async {
      if (!await launchUrl(_url)) {
        throw Exception('Could not launch $_url');
      }
    }

    Future<void> _makePhoneCall() async {
      final Uri launchUri = Uri(
        scheme: 'tel',
        path: phoneNumber,
      );
      await launchUrl(launchUri);
    }

    Future<void> _pickImage() async {
      final imagePicker = ImagePicker();
      final pickedImage = await imagePicker.pickImage(
        source: ImageSource.gallery,
      );

      setState(() {
        _pickedImage = pickedImage!;
        _teamLogoController.text = pickedImage.path;
      });
    }

    void _addPlayerToList(Map<String, dynamic> player) {
      if (player['username'].isNotEmpty &&
          !_teamMembersList.any((existingPlayer) =>
              existingPlayer['username'] == player['username'])) {
        setState(() {
          _teamMembersList.add(player);
          _teamPlayersController.clear();
        });
      }
    }

    void _removePlayer(int index) {
      setState(() {
        _teamMembersList.removeAt(index);
      });
    }

    Future<void> submitProfile() async {
      final List<int> teamMemberIds =
          _teamMembersList.map((member) => member['id'] as int).toList();

      final Map<String, dynamic> data = {
        'name': _nameController.text,
        'contact_number': _contactNumberController.text,
        'ign': _ignNumberController.text,
        'id_number': _idNumberController.text,
        'discord_id': _discordIdController.text,
        'number_of_players': _numberOfPlayersController.text,
        'team_players': teamMemberIds,
        'game_id': _gameIdController.text,
        'server_id': _serverIdController.text
      };

      if (teamMemberIds.length < 5) {
        return showScaffoldMessenger(
            context, 'You must select 5 team members at least.');
      }

      File teamLogo = File(_pickedImage.path);

      if (_formKey.currentState!.validate()) {
        try {
          var auth = Provider.of<Auth>(context, listen: false);
          auth.mlbbRegistration(data, teamLogo).then((_) {
            showScaffoldMessenger(context, 'Thank you for participating.');
            Navigator.of(context).pushNamed(UserScreen.routeName);
          }).catchError((onError) {
            showScaffoldMessenger(context, 'Opps! Could not register now.');
          });
        } catch (error) {
          showScaffoldMessenger(context, 'Opps! Some network error occured.');
        }
      } else {
        showScaffoldMessenger(context, 'You missed something. Please check.');
      }
    }

    return Scaffold(
      appBar:
          header(context: context, titleText: "MLBB X Otaku Jatra Winter 2024"),
      body: _isLoading
          ? Loading()
          : _mlbbTicketPurchased
              ? SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        opacity: 0.1,
                        image: CachedNetworkImageProvider(
                            "${Url.mediaUrl}/assets/doodle.jpg"),
                        fit: BoxFit.fill,
                      ),
                    ),
                    child: Column(
                      children: [
                        SizedBox(height: 20),
                        Container(
                          width: 150,
                          height: 170,
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage(
                                  'assets/images/winter_championship.png'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'MLBB X Otaku Jatra Winter 2024: Winters Cup Championship Registration Form',
                          style: TextStyle(
                            fontSize: 22,
                            // color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'This is the official form for Otaku Jatra Winter 2024: MLBB 5v5 All Star Tournament Registration.',
                          style: textStyle,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Please read carefully and fill up your details properly to avoid any confusion.',
                          style: boldTextStyle,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'The registration fee is NRS. 250 for the whole squad.',
                          style: boldTextStyle,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Rules and regulations:',
                          style: boldTextStyle,
                        ),
                        SizedBox(height: 10),
                        Text(
                          '1. Trash talking and unfair gameplay will be immediately disqualified from the tournament.',
                          style: textStyle,
                        ),
                        SizedBox(height: 10),
                        Text(
                          '2. Attacking and sending vulgar messages to opponent team will lead to disqualification.',
                          style: textStyle,
                        ),
                        SizedBox(height: 10),
                        Text(
                          '3. Once registered you cannot change the team members or accounts.',
                          style: textStyle,
                        ),
                        SizedBox(height: 10),
                        Text(
                          '4. All teams must check their match schedule, be ready 15 min before the match and will be contacted by the host for preparation.',
                          style: textStyle,
                        ),
                        SizedBox(height: 10),
                        Text(
                          '5. Each team needs their team logo and must upload it to the form.',
                          style: textStyle,
                        ),
                        SizedBox(height: 10),
                        Text(
                          '6. The team can only register 5 players and 2 subs (Total 7 players).',
                          style: textStyle,
                        ),
                        SizedBox(height: 10),
                        Text(
                          '7. Player must show there login history in the beginning and after the end of the game as well.',
                          style: textStyle,
                        ),
                        SizedBox(height: 10),
                        Text(
                          '8. All the details will be provided on Otaku Jatra Page and Discord.',
                          style: textStyle,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Competition details:',
                          style: boldTextStyle,
                        ),
                        SizedBox(height: 10),
                        Text(
                          '1. Each team after registration will be directly adjusted to the tie-sheet there will be no group stages.',
                          style: textStyle,
                        ),
                        SizedBox(height: 10),
                        Text(
                          '2. The games will be in bracket knock out system and will be held online till quarter-finals.',
                          style: textStyle,
                        ),
                        SizedBox(height: 10),
                        Text(
                          '3. Tournament Lobby will be hosted.                                      ',
                          style: textStyle,
                        ),
                        SizedBox(height: 10),
                        Text(
                          '4. Matches till quarter-finals and the semi-finals will be best of 3, and finals will be best of 5.',
                          style: textStyle,
                        ),
                        SizedBox(height: 10),
                        Text(
                          '5. The Grand Finale will be held on the day of the main event on Jan 27, 2024.',
                          style: textStyle,
                        ),
                        SizedBox(height: 10),
                        Text(
                          '6. The finalist teams will get free entry on the day of the main event.',
                          style: textStyle,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Prize pool: NRP 100,000 & 100,000 diamonds ',
                          style: boldTextStyle,
                        ),
                        SizedBox(height: 10),
                        Text(
                          '1st prize: 50,000 NRP & 40,000 diamonds',
                          style: textStyle,
                        ),
                        SizedBox(height: 10),
                        Text(
                          '2nd prize: 30,000 NRP & 25,000 diamonds',
                          style: textStyle,
                        ),
                        SizedBox(height: 10),
                        Text(
                          '3rd prize: 20,000 NRP & 15,000 diamonds',
                          style: textStyle,
                        ),
                        SizedBox(height: 10),
                        Text(
                          '4th to 8th prize: 5000 diamonds for each team',
                          style: textStyle,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Each player from every team will get a certificate for participating in the competition.',
                          style: textStyle,
                        ),
                        SizedBox(height: 20),
                        // Text(
                        //   'Payment for registration must be done through the given QR code below and the payment screenshot is required. If payment screen shot isn\'t included the registration will not be accepted.',
                        //   style: boldTextStyle,
                        // ),
                        // SizedBox(height: 20),
                        Text(
                          'Please fill out your information so that we can manage your schedules.',
                          style: boldTextStyle,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'The tournament will start after the registrations close.',
                          style: boldTextStyle,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Finalist will be provided their passes on the day of the event.',
                          style: boldTextStyle,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'DEADLINE for the  Registration is Jan 15 , 2024.',
                          style: TextStyle(
                            fontSize: 16,
                            // color: Colors.white,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        SizedBox(height: 20),
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                            ),
                            children: [
                              TextSpan(
                                text:
                                    'Please contact our Gaming Coordinator at ',
                              ),
                              TextSpan(
                                text: 'MISO 9808335630',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    _makePhoneCall();
                                  },
                              ),
                              TextSpan(
                                text: ' if you have further queries.',
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 20),
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              _launchDiscordUrl();
                            },
                            child: Container(
                              width: double.infinity,
                              height: 230,
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Stack(
                                children: [
                                  Container(
                                    width: double.infinity,
                                    height: double.infinity,
                                    decoration: BoxDecoration(
                                      image: DecorationImage(
                                        image: AssetImage(
                                            'assets/images/discord.png'),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 30,
                                    ),
                                    margin: EdgeInsets.all(10),
                                    color: Colors
                                        .transparent, // Make the container transparent
                                    child: Column(
                                      children: [
                                        SizedBox(height: 100),
                                        Text(
                                          'All team members must join Otaku Jatra discord. Click here to join.',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Container(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: TextFormField(
                                    decoration: InputDecoration(
                                      labelText: 'Team Name  *',
                                      prefixIcon: Icon(Icons.person),
                                    ),
                                    textInputAction: TextInputAction.next,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your team name';
                                      }
                                      return null;
                                    },
                                    controller: _nameController,
                                  ),
                                ),
                              ),
                              Container(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: TextFormField(
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Contact Number  *',
                                      prefixIcon: Icon(Icons.phone),
                                    ),
                                    textInputAction: TextInputAction.next,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your team\'s contact number';
                                      }
                                      return null;
                                    },
                                    controller: _contactNumberController,
                                  ),
                                ),
                              ),
                              Container(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: TextFormField(
                                    decoration: InputDecoration(
                                      labelText: 'In Game Name (IGN)  *',
                                      prefixIcon: Icon(
                                        FontAwesome5.gamepad,
                                      ),
                                    ),
                                    textInputAction: TextInputAction.next,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your in game name (IGN)';
                                      }
                                      return null;
                                    },
                                    controller: _ignNumberController,
                                  ),
                                ),
                              ),
                              Container(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: TextFormField(
                                    decoration: InputDecoration(
                                      labelText:
                                          'Team Leader ID & Server Number  *',
                                      hintText: 'Eg: 73827282 (2090)',
                                      prefixIcon: Icon(FontAwesome5.id_card),
                                    ),
                                    textInputAction: TextInputAction.next,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your team leader ID number';
                                      }
                                      return null;
                                    },
                                    controller: _idNumberController,
                                  ),
                                ),
                              ),
                              Container(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: TextFormField(
                                    decoration: InputDecoration(
                                      labelText: 'Discord ID  *',
                                      prefixIcon: Icon(FontAwesome5.discord),
                                    ),
                                    textInputAction: TextInputAction.next,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your Discord ID';
                                      }
                                      return null;
                                    },
                                    controller: _discordIdController,
                                  ),
                                ),
                              ),
                              Container(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: TextFormField(
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Number of Players  *',
                                      prefixIcon: Icon(FontAwesome5.users),
                                    ),
                                    textInputAction: TextInputAction.next,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your Number of Players';
                                      }
                                      return null;
                                    },
                                    controller: _numberOfPlayersController,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: TextFormField(
                                        decoration: InputDecoration(
                                          labelText:
                                              'Select Players [Baakhapaa username] *',
                                          prefixIcon:
                                              Icon(FontAwesome5.user_plus),
                                        ),
                                        textInputAction: TextInputAction.next,
                                        controller: _teamPlayersController,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      var auth = Provider.of<Auth>(context,
                                          listen: false);

                                      auth
                                          .showUser(_teamPlayersController.text)
                                          .then((value) {
                                        _addPlayerToList(auth.teamMember);
                                      }).catchError((onError) {
                                        showScaffoldMessenger(context,
                                            'Opps! Baakhapaa user not found.');
                                      });
                                    },
                                    child: Text('Add'),
                                  ),
                                ],
                              ),
                              if (_teamMembersList.isNotEmpty)
                                Column(
                                  children: [
                                    SizedBox(height: 20),
                                    Text('Team Members:', style: boldTextStyle),
                                    Text('NOTE: Please include your self too.',
                                        style: TextStyle(
                                            fontStyle: FontStyle.italic)),
                                    ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: _teamMembersList.length,
                                      itemBuilder: (context, index) {
                                        final player = _teamMembersList[index];
                                        return ListTile(
                                          leading: CircleAvatar(
                                            backgroundImage:
                                                CachedNetworkImageProvider(
                                                    player['image']),
                                          ),
                                          title: Text(
                                              '${player['id']} - ${player['username']}'),
                                          trailing: TextButton(
                                            child: Text(
                                              'Remove',
                                              style:
                                                  TextStyle(color: Colors.red),
                                            ),
                                            onPressed: () {
                                              _removePlayer(index);
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                    SizedBox(height: 20),
                                  ],
                                ),
                              Container(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: TextFormField(
                                    decoration: InputDecoration(
                                      labelText:
                                          'Team member\'s game & server id *',
                                      hintText:
                                          'Eg: 73827282 (2090), 163736282 (3728), 26772727 (0908)',
                                      prefixIcon: Icon(Icons.info),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your team member\'s game & server id';
                                      }
                                      return null;
                                    },
                                    textInputAction: TextInputAction.next,
                                    controller: _gameIdController,
                                  ),
                                ),
                              ),
                              // Container(
                              //   child: Padding(
                              //     padding: const EdgeInsets.all(8.0),
                              //     child: TextFormField(
                              //       decoration: InputDecoration(
                              //         labelText: 'Team member\'s server id',
                              //         prefixIcon: Icon(Icons.info),
                              //       ),
                              //       textInputAction: TextInputAction.next,
                              //       controller: _serverIdController,
                              //     ),
                              //   ),
                              // ),
                              Container(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: <Widget>[
                                          Expanded(
                                            child: TextFormField(
                                              decoration: InputDecoration(
                                                labelText:
                                                    'Team Logo less than 2mb *',
                                                prefixIcon: Icon(
                                                    FontAwesome5.file_image),
                                              ),
                                              validator: (value) {
                                                if (value == null ||
                                                    value.isEmpty) {
                                                  return 'Please select team logo less than 2mb';
                                                }
                                                return null;
                                              },
                                              textInputAction:
                                                  TextInputAction.next,
                                              controller: _teamLogoController,
                                              readOnly: true,
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: _pickImage,
                                            child: Text('Select Team Logo'),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        children: [
                                          SizedBox(height: 20),
                                          Container(
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                // color: Colors.white,
                                                width: 2.0,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8.0),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.grey
                                                      .withValues(alpha: 0.5),
                                                  spreadRadius: 2,
                                                  blurRadius: 5,
                                                  offset: Offset(0, 3),
                                                ),
                                              ],
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8.0),
                                              child: Image.file(
                                                File(_pickedImage.path),
                                                height: 100,
                                                width: 100,
                                              ),
                                            ),
                                          ),
                                          SizedBox(height: 10),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: InkWell(
                                  onTap: () {
                                    if (_formKey.currentState!.validate()) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text('Processing...')),
                                      );
                                    }
                                    submitProfile();
                                  },
                                  child: AppButttons(
                                    size: double.infinity,
                                    backgroundColor: Color(0xff73d9de),
                                    text: "Submit",
                                    textColor: Colors.black,
                                    borderColor: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Thank you for your Participation!!!',
                          style: textStyle,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Hope you have a great time at your very own Otaku Jatra Winters Cup 2024.',
                          style: textStyle,
                        ),
                        SizedBox(height: 20),
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                            ),
                            children: [
                              TextSpan(
                                text:
                                    'Please contact our Gaming Coordinator at ',
                              ),
                              TextSpan(
                                text: 'MISO 9808335630',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    _makePhoneCall();
                                  },
                              ),
                              TextSpan(
                                text: ' if you have further queries.',
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 60),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        opacity: 0.1,
                        image: CachedNetworkImageProvider(
                            "${Url.mediaUrl}/assets/doodle.jpg"),
                        fit: BoxFit.fill,
                      ),
                    ),
                    child: Column(
                      children: [
                        SizedBox(height: 20),
                        Container(
                          width: 150,
                          height: 170,
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage(
                                  'assets/images/winter_championship.png'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'MLBB X Otaku Jatra Winter 2024',
                          style: TextStyle(
                            fontSize: 22,
                            // color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'To Access: Winters Cup Championship Registration Form',
                          style: boldTextStyle,
                        ),
                        SizedBox(height: 20),
                        Text(
                          '1. You must first purchase a ticket from the Baakhapaa Store. This purchase serves as your team\'s entry into the tournament.',
                          style: textStyle,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'The registration fee is NRS. 250 for the whole squad.',
                          style: boldTextStyle,
                        ),
                        SizedBox(height: 20),
                        TextButton(
                          child: Text(
                              'CLICK HERE >> MLBB X Otaku Jatra Winter 2024 Ticket'),
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              SingleProductScreen.routeName,
                              arguments: 118,
                            );
                          },
                        ),
                        SizedBox(height: 20),
                        Text(
                          'DEADLINE for the  Registration is Jan 15 , 2024.',
                          style: TextStyle(
                            fontSize: 16,
                            // color: Colors.white,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          '2. Only one ticket purchase is required per team. The team leader handles this responsibility.',
                          style: textStyle,
                        ),
                        SizedBox(height: 20),
                        Text(
                          '3. The registration form will only become available after the ticket purchase has been fully processed and marked as "Completed" in the store\'s system. This ensures that payment has been confirmed.',
                          style: textStyle,
                        ),
                        SizedBox(height: 20),
                        Text(
                          '4. All players must have individual Baakhapaa user accounts. The team leader will add each player to the team\'s slot using their respective Baakhapaa usernames within the registration form.',
                          style: textStyle,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Prize pool: NRP 100,000 & 100,000 diamonds ',
                          style: boldTextStyle,
                        ),
                        SizedBox(height: 10),
                        Text(
                          '1st prize: 50,000 NRP & 40,000 diamonds',
                          style: textStyle,
                        ),
                        SizedBox(height: 10),
                        Text(
                          '2nd prize: 30,000 NRP & 25,000 diamonds',
                          style: textStyle,
                        ),
                        SizedBox(height: 10),
                        Text(
                          '3rd prize: 20,000 NRP & 15,000 diamonds',
                          style: textStyle,
                        ),
                        SizedBox(height: 10),
                        Text(
                          '4th to 8th prize: 5000 diamonds for each team',
                          style: textStyle,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Each player from every team will get a certificate for participating in the competition.',
                          style: textStyle,
                        ),
                        SizedBox(height: 20),
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                            ),
                            children: [
                              TextSpan(
                                text:
                                    'Please contact our Gaming Coordinator at ',
                              ),
                              TextSpan(
                                text: 'MISO 9808335630',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    _makePhoneCall();
                                  },
                              ),
                              TextSpan(
                                text: ' if you have further queries.',
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Thank You!',
                          style: textStyle,
                        ),
                        SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),
    );
  }
}
