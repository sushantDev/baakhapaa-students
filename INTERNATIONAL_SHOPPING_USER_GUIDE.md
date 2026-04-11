# Baakhapaa International Shopping — User Guide

**Audience:** Product team, customer support, content creators, and anyone who wants to understand what international buyers experience on Baakhapaa.

---

## 1. What Changed?

Baakhapaa's shop now works internationally. Buyers anywhere in the world can:

- Browse and purchase products in **US Dollars (USD)**
- Pay with **Visa, Mastercard, or any debit/credit card** (powered by Stripe)
- Enter their **international shipping address**
- Choose from multiple **international courier options** (DHL, FedEx, Nepal Post EMS, Aramex)
- Receive active **shipment tracking** with real-time status updates

Nepali buyers keep their existing experience — they can continue paying in NPR with Khalti, COD, or now also card.

---

## 2. The Full Shopping Journey (Step by Step)

### Step 1 — Finding a Product

The user browses the Baakhapaa shop just like before. No change in how products are listed or searched. Prices are still shown in Nepali Rupees (NPR).

---

### Step 2 — Adding to Cart

Products are added to the cart as normal. The cart shows:

- Item names and quantities
- Total price in NPR

---

### Step 3 — Choosing How to Pay

When the buyer taps **"Place Order"**, a payment options dialog appears:

| Option                   | Who it's for                     | Currency |
| ------------------------ | -------------------------------- | -------- |
| 🔵 **Khalti**            | Nepali users                     | NPR      |
| 💵 **Cash on Delivery**  | Nepali users                     | NPR      |
| 💳 **Credit/Debit Card** | Anyone, especially international | USD      |

International buyers choose **Credit/Debit Card**.

---

### Step 4 — Entering a Shipping Address

After selecting card payment, the app checks whether the buyer has any saved shipping addresses.

**First-time international buyer:**

- The app opens the **Shipping Address** screen automatically
- The buyer fills in:
  - Recipient name
  - Phone number
  - Address line 1 & 2
  - City, State/Province
  - Postal code
  - Country (2-letter code like `US`, `GB`, `AU`) and country name
  - Option to set as default address
- Once saved, this address is used for the current order

**Returning buyer with saved address:**

- Their default address is already selected
- They can see the selected address and change it if needed

---

### Step 5 — Choosing a Shipping Courier

After confirming the address, the app shows a **Choose Shipping** bottom sheet with available couriers for the buyer's country.

For each courier the buyer sees:

- Courier name (DHL, FedEx, Nepal Post EMS, Aramex)
- Estimated delivery time (e.g., "3–5 business days")
- Shipping cost in **USD** (e.g., $20.00)

The buyer taps to select one and confirms.

> **Note:** Shipping options are tailored to the buyer's country. Some couriers may not serve all regions.

---

### Step 6 — Reviewing the Total

At this point the app has calculated:

- Products subtotal (NPR converted to USD using today's live exchange rate)
- Shipping cost (USD)
- **Grand total in USD**

The exchange rate is automatically fetched from a live rate service and refreshed every 6 hours. The buyer sees a real-time, accurate USD price.

---

### Step 7 — Entering Card Details

The Stripe payment sheet appears — a secure, native card entry screen:

- Card number
- Expiry date
- CVV
- Name on card (optional, auto-populated)

This screen is provided by Stripe and is fully **PCI compliant**. Baakhapaa never sees or stores card numbers.

---

### Step 8 — Payment Confirmation

Once the buyer taps **Pay**:

1. Stripe processes the payment
2. Baakhapaa's server verifies the payment is genuinely successful
3. The order is created with the selected shipping address and courier
4. A success screen appears: "Order Placed!"

The seller and shipping team now receive the order with the full delivery address.

---

### Step 9 — Tracking the Order

The buyer can track their order any time from their **Order History**:

They see a **status card** showing where their package is:

| Status              | What it means                            |
| ------------------- | ---------------------------------------- |
| 🕐 Order Received   | Baakhapaa has received the order         |
| ⚙️ Processing       | The seller is preparing the items        |
| 📦 Packed           | Items are packed and ready to ship       |
| 🚚 Shipped          | Package handed to the courier            |
| ✈️ In Transit       | Package is on its way internationally    |
| 🛵 Out for Delivery | Package is with the local delivery agent |
| ✅ Delivered        | Package arrived!                         |

A **progress bar** fills up as the status advances. Below the card, a full **tracking timeline** shows every scan event with:

- The exact status change
- Location where it was scanned
- Description (e.g., "Departed Kathmandu hub")
- Date and time

If the courier provides a tracking URL, a **"Track on DHL/FedEx website"** button appears so the buyer can check directly on the courier's site.

---

## 3. Shipping Coverage

Baakhapaa ships to **7 major regions** from Nepal:

| Region              | Example Countries                      |
| ------------------- | -------------------------------------- |
| South Asia          | India, Bangladesh, Sri Lanka, Pakistan |
| Southeast Asia      | Thailand, Singapore, Malaysia, Vietnam |
| East Asia           | Japan, South Korea, China, Hong Kong   |
| Middle East         | UAE, Saudi Arabia, Qatar, Kuwait       |
| Europe              | UK, Germany, France, Netherlands       |
| North America       | USA, Canada                            |
| Australia & Pacific | Australia, New Zealand                 |

> Coverage expands as new couriers are added. Customers in countries not listed yet will not see the card payment option for physical goods.

---

## 4. Available Couriers (Shipped from Nepal)

| Courier                 | Best for                | Approx. Speed |
| ----------------------- | ----------------------- | ------------- |
| **Nepal Post EMS**      | Budget-conscious buyers | 7–21 days     |
| **Aramex**              | Middle East & Asia      | 5–10 days     |
| **DHL Express**         | Fast delivery worldwide | 3–7 days      |
| **FedEx International** | Premium fast delivery   | 3–7 days      |

Actual shipping cost depends on the destination country and total package weight. The app calculates this automatically.

---

## 5. Currency & Pricing

- All card payments are charged in **USD**
- Prices are converted from NPR to USD using a **live exchange rate** fetched directly from an exchange rate service
- The rate is updated every 6 hours
- Baakhapaa admin can also set a manual rate if needed (e.g., to lock in a rate during volatile periods)
- The buyer always sees the final USD amount before confirming payment — no surprises

---

## 6. Managing Shipping Addresses

Buyers can save **multiple shipping addresses** (home, office, family abroad, etc.):

- Set a **default address** that pre-fills at checkout
- Delete old addresses
- Add new addresses at any time from the checkout flow or their profile

---

## 7. What Sellers & Admins See

When an international order comes in, the seller/admin can see:

- The full shipping address (recipient, phone, address, country)
- Which courier was selected
- The shipping cost included in the order
- A place to enter the tracking number once the item ships

Once a tracking number is entered and the courier updates confirmed, the buyer sees live status updates in the app.

---

## 8. Common Questions

**Q: Do I have to pay in USD?**
A: Card payments are in USD. Khalti and COD remain in NPR. Nepali buyers can use any option.

**Q: Is my card information safe?**
A: Yes. Card details are handled entirely by Stripe — Baakhapaa never sees or stores them.

**Q: Can I ship to any country?**
A: Currently 7 major regions are supported. If your country doesn't show shipping options, try changing your country code to the nearest supported region or contact support.

**Q: How long does delivery take?**
A: Depends on the courier you choose and your destination. Nepal Post EMS is slowest (7–21 days), DHL/FedEx fastest (3–7 days).

**Q: Can I track my order?**
A: Yes. Once the seller ships your order and enters a tracking number, you'll see live updates in the Baakhapaa app under Order History.

**Q: What's the cheapest shipping option?**
A: Nepal Post EMS is generally the most affordable. DHL and FedEx are faster but cost more.
