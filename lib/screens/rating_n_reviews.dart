import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/screens/WriteReview.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class RatingAndReviews extends StatelessWidget {
  const RatingAndReviews({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> reviews = [
      {
        'name': 'Courtney Henry',
        'photo': ImagePaths.user10,
        'rating': 5,
        'timePosted': '2 mins ago',
        'reviewText':
            'I had a very good experience with this doctor. The consultation was clear and the doctor explained everything in detail. The staff was polite and the process was smooth from booking to follow-up. I truly appreciate the care and will recommend this clinic to others.',
      },
      {
        'name': 'Cameron Williamson',
        'photo': ImagePaths.user11,
        'rating': 4,
        'timePosted': '2 mins ago',
        'reviewText':
            'The doctor was very kind and explained everything clearly. I felt comfortable and well cared for.',
      },
      {
        'name': 'Jane Cooper',
        'photo': ImagePaths.user12,
        'rating': 3,
        'timePosted': '2 mins ago',
        'reviewText':
            'I had a great experience with the doctor. He explained everything in detail and made sure I understood the treatment plan. The consultation was smooth and the staff was also very supportive. Overall, I felt comfortable and confident with the care I received.',
      },
    ];
    return Scaffold(
      appBar: AppBar(
        leading: CustomBackButton(),
        automaticallyImplyLeading: false,
        title: CustomText(
          text: "Raing & Reviews",
          fontSize: 16.78,
          fontFamily: "Gilroy-Bold",
          fontWeight: FontWeight.bold,
          color: AppColors.primary500,
          letterSpacing: -0.31,
          lineHeight: 1.0,
        ),
      ),
      body: Column(
        children: [
          RatingsWidget(),
          Expanded(
            child: ListView.builder(
              itemCount: 3,
              itemBuilder: (ctx, i) {
                final review = reviews[i];
                return (ReviewsWidget(
                  name: review["name"],
                  photo: review["photo"],
                  rating: review["rating"],
                  reviewText: review["reviewText"],
                  timeStamp: review["timePosted"],
                ));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class RatingsWidget extends StatelessWidget {
  const RatingsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: ScallingConfig.scale(10)),
      decoration: BoxDecoration(
        color: AppColors.veryLightGrey,
        borderRadius: BorderRadius.circular(ScallingConfig.moderateScale(18)),
      ),
      width: Utils.windowWidth(context) * 0.9,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: ScallingConfig.scale(20),
          vertical: ScallingConfig.verticalScale(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i in [1, 2, 3, 4, 5].reversed) ...[
                  CustomRatingHorizontalBar(rating: i),
                  SizedBox(height: ScallingConfig.scale(5)),
                ],
              ],
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomText(
                  text: "4.0",
                  fontSize: 38,
                  fontFamily: "Gilroy-Bold",
                  fontWeight: FontWeight.w400,
                  color: AppColors.themeDarkGrey,
                ),

                RatingBar.builder(
                  initialRating: 4.0,
                  minRating: 1,
                  itemSize: ScallingConfig.scale(15),
                  direction: Axis.horizontal,
                  allowHalfRating: true,
                  itemCount: 5,
                  itemPadding: EdgeInsets.symmetric(horizontal: 1),
                  itemBuilder: (context, _) => Icon(
                    Icons.star,
                    size: ScallingConfig.scale(5),
                    color: Colors.amber,
                  ),
                  onRatingUpdate: (rating) {
                    //  debugPrint(rating);
                  },
                ),
                CustomText(
                  text: "52 Reviews",
                  fontSize: 14,
                  fontFamily: "Gilroy-SemiBold",
                  fontWeight: FontWeight.w400,
                  color: AppColors.themeDarkGrey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ReviewsWidget extends StatelessWidget {
  const ReviewsWidget({
    super.key,
    this.name = "",
    this.rating = 3,
    this.reviewText = '',
    this.timeStamp = '',
    this.photo,
  });
  final String name;
  final dynamic rating;
  final String reviewText;
  final String timeStamp;
  final String? photo;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.white),
      // padding:EdgeInsets.symmetric(horizontal: ScallingConfig.scale(10)),
      width: Utils.windowWidth(context),
      padding: EdgeInsets.symmetric(
        vertical: ScallingConfig.verticalScale(20),
        horizontal: ScallingConfig.scale(10),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(
                radius: ScallingConfig.scale(20),
                backgroundImage: AssetImage(photo ?? ImagePaths.user7),
              ),
              SizedBox(width: ScallingConfig.scale(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    CustomText(
                      text: name,
                      color: AppColors.themeDarkGrey,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    Row(
                      children: [
                        RatingBar.builder(
                          initialRating: rating.toDouble(),
                          minRating: 1,
                          itemSize: ScallingConfig.scale(15),
                          direction: Axis.horizontal,
                          allowHalfRating: true,
                          itemCount: 5,

                          itemPadding: EdgeInsets.symmetric(horizontal: 1),
                          itemBuilder: (context, _) => Icon(
                            Icons.star,
                            size: ScallingConfig.scale(5),
                            color: Colors.amber,
                          ),
                          onRatingUpdate: (rating) {
                            //  debugPrint(rating);
                          },
                        ),
                        CustomText(
                          text: timeStamp,
                          fontFamily: "Gilroy-Medium",
                          fontWeight: FontWeight.w400,
                          fontSize: ScallingConfig.moderateScale(12),
                          color: AppColors.primary500,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              CustomText(
                text: "Write Review",
                underline: true,
                fontFamily: "Gilroy-Medium",
                fontWeight: FontWeight.w400,
                fontSize: ScallingConfig.moderateScale(12),
                color: AppColors.themeDarkGrey,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (ctx) => WrtieReviewScreen()),
                  );
                },
              ),
            ],
          ),
          CustomText(
            fontFamily: "Gilroy-Regular",
            fontSize: ScallingConfig.moderateScale(12),
            maxLines: 10,
            fontWeight: FontWeight.w400,
            color: AppColors.primary500,
            text: reviewText,
          ),
        ],
      ),
    );
  }
}

class CustomRatingHorizontalBar extends StatelessWidget {
  const CustomRatingHorizontalBar({super.key, this.rating = 1});
  final dynamic rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      // mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        CustomText(
          text: rating.toString(),
          fontFamily: "Gilroy-Medium",
          fontSize: 14,
          color: AppColors.themeDarkGrey,
          fontWeight: FontWeight.w400,
        ),
        SizedBox(width: ScallingConfig.scale(10)),
        Icon(Icons.star, color: Colors.amber),
        SizedBox(width: ScallingConfig.scale(10)),
        Container(
          width: (ScallingConfig.scale(14) + rating) * rating,
          height: ScallingConfig.scale(10),
          decoration: BoxDecoration(
            color: AppColors.darkGray500,
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ],
    );
  }
}
