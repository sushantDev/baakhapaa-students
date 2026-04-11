import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/widgets/app_button.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DonateForCause extends StatefulWidget {
  @override
  _DonateForCauseState createState() => _DonateForCauseState();
}

class _DonateForCauseState extends State<DonateForCause> {
  void openDonationModal(BuildContext context, String cause) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows control of sheet height
      builder: (BuildContext context) {
        TextEditingController donationController = TextEditingController();

        void fillDonation(int points) {
          donationController.text = points.toString();
        }

        void donate(int shortsId, cause) async {
          var authProvider = Provider.of<Auth>(context, listen: false);
          int donationAmt = int.parse(donationController.text);

          if (donationAmt > authProvider.userAvailableCoins) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Insufficient baakhapaa points in your account.'),
            ));
            Navigator.pop(context);
            return;
          }

          await authProvider
              .donation(
            donationAmt,
            shortsId,
            'Donation for $cause',
            'shorts',
          )
              .then((value) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Thank you for your donation.'),
            ));
            Navigator.pop(context);
          });
        }

        return FractionallySizedBox(
          heightFactor: 0.6, // Modal opens at 60% of the screen height
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context)
                  .viewInsets
                  .bottom, // Avoids modal being hidden by keyboard
              left: 16.0,
              right: 16.0,
              top: 16.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Donate for $cause',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton(
                      onPressed: () => fillDonation(10),
                      child: Text('10'),
                    ),
                    ElevatedButton(
                      onPressed: () => fillDonation(20),
                      child: Text('20'),
                    ),
                    ElevatedButton(
                      onPressed: () => fillDonation(50),
                      child: Text('50'),
                    ),
                    ElevatedButton(
                      onPressed: () => fillDonation(100),
                      child: Text('100'),
                    ),
                    ElevatedButton(
                      onPressed: () => fillDonation(500),
                      child: Text('500'),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                TextField(
                  controller: donationController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Enter Baakhapaa Points',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: InkWell(
                    onTap: () {
                      var shortsId = cause == 'Plant Trees' ? 253 : 254;
                      donate(shortsId, cause);
                    },
                    child: AppButttons(
                      size: double.infinity,
                      backgroundColor: Color(0xff73d9de),
                      text: "Donate",
                      textColor: Colors.black,
                      borderColor: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DONATE FOR CAUSE',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => openDonationModal(context, 'Plant Trees'),
                  child: Container(
                    padding: EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: CachedNetworkImageProvider(
                            'https://bkp-v1.blr1.cdn.digitaloceanspaces.com/assets/plant_trees.jpg'), // Replace with actual image URL
                        fit: BoxFit.cover,
                      ),
                      borderRadius: BorderRadius.circular(8.0),
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    child: Text(
                      'Plant Trees',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => openDonationModal(context, 'Hungry Kids'),
                  child: Container(
                    padding: EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: CachedNetworkImageProvider(
                            'https://bkp-v1.blr1.cdn.digitaloceanspaces.com/assets/hungry_kids.jpg'), // Replace with actual image URL
                        fit: BoxFit.cover,
                      ),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Text(
                      'Hungry Kids',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
