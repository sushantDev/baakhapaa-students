import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ReferralCodeForm extends StatefulWidget {
  final Function(String) onSubmit;
  final TextEditingController controller;

  ReferralCodeForm({required this.onSubmit, required this.controller});

  @override
  _ReferralCodeFormState createState() => _ReferralCodeFormState();
}

class _ReferralCodeFormState extends State<ReferralCodeForm> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Apply referral code',
          style: TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 8),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.amber),
                  SizedBox(width: 8),
                  Text(
                    'How it works:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              SizedBox(height: 6),
              Text(
                '• Enter a friend\'s username as your referral code',
                style: TextStyle(fontSize: 13),
              ),
              Text(
                '• Both you and your friend receive 25 bonus points after you earn 25 points',
                style: TextStyle(fontSize: 13),
              ),
              Text(
                '• Unlock special achievements for referrals [If applicable]',
                style: TextStyle(fontSize: 13),
              ),
              Text(
                '• Please skip if you have no referral code',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Form(
          key: _formKey,
          child: TextFormField(
            autofocus: true,
            style: TextStyle(color: Colors.black),
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Input your referral code',
              labelStyle: TextStyle(color: Colors.black),
              fillColor: Colors.white,
              filled: true,
              prefixIcon: Icon(
                Icons.person_add,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Color.fromARGB(255, 9, 9, 9),
              ),
            ),
            validator: (value) {
              if (value == null) return 'Please input referral code.';
              if (value == Provider.of<Auth>(context, listen: false).username)
                return 'You cannot refer yourself.';
              return null;
            },
            controller: widget.controller,
          ),
        ),
        SizedBox(height: 20),
        InkWell(
          onTap: () {
            if (_formKey.currentState!.validate()) {
              widget.onSubmit(widget.controller.text);
            }
          },
          child: AppButttons(
            textColor: Colors.white,
            backgroundColor: Colors.blue,
            borderColor: Colors.black,
            text: 'Submit',
            size: 250,
          ),
        ),
      ],
    );
  }
}
