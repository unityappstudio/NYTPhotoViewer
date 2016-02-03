//
//  NYTPhotoViewController.m
//  Pods
//
//  Created by Brian Capps on 2/11/15.
//
//

#import "NYTPhotoViewController.h"
#import "NYTPhoto.h"
#import "NYTScalingImageView.h"

#import "SDWebImageManager.h"

NSString* const NYTPhotoViewControllerPhotoImageUpdatedNotification = @"NYTPhotoViewControllerPhotoImageUpdatedNotification";

@interface NYTPhotoViewController () <UIScrollViewDelegate, UIGestureRecognizerDelegate>

@property (nonatomic) id <NYTPhoto> photo;

@property (nonatomic) NYTScalingImageView* scalingImageView;
@property (nonatomic) UIView* loadingView;
@property (nonatomic) NSNotificationCenter* notificationCenter;
@property (nonatomic) UITapGestureRecognizer* doubleTapGestureRecognizer;
@property (nonatomic) UILongPressGestureRecognizer* longPressGestureRecognizer;

@end

@implementation NYTPhotoViewController

- (instancetype)initWithCoder:(NSCoder*)aDecoder {
    @throw [NSException exceptionWithName:@"NYTPhotoViewController" reason:@"Must initWithPhoto:loadingView: instead." userInfo:nil];
    return [self initWithPhoto:nil loadingView:nil notificationCenter:nil];
}

#pragma mark - NSObject

- (void)dealloc {
    _scalingImageView.delegate = nil;

    [_notificationCenter removeObserver:self];
}

#pragma mark - UIViewController

- (instancetype)initWithNibName:(NSString*)nibNameOrNil bundle:(NSBundle*)nibBundleOrNil {
    return [self initWithPhoto:nil loadingView:nil notificationCenter:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self.notificationCenter addObserver:self selector:@selector(photoImageUpdatedWithNotification:) name:NYTPhotoViewControllerPhotoImageUpdatedNotification object:nil];

    self.scalingImageView.frame = self.view.bounds;
    [self.view addSubview:self.scalingImageView];

    [self.view addSubview:self.loadingView];
    [self.loadingView sizeToFit];

    [self.view addGestureRecognizer:self.doubleTapGestureRecognizer];
    [self.view addGestureRecognizer:self.longPressGestureRecognizer];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];

    self.scalingImageView.frame = self.view.bounds;

    [self.loadingView sizeToFit];
    self.loadingView.center = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds));
}

#pragma mark - NYTPhotoViewController

- (void)loadImageAtItem:(id <NYTPhoto>)photo {
    SDWebImageManager* manager = [SDWebImageManager sharedManager];
    __weak __typeof(self) weakSelf = self;
    [manager cachedImageExistsForURL:[NSURL URLWithString:photo.urlThumbString]
                          completion:^(BOOL isInCache) {
          if (isInCache) {
              UIImage* thumbImage = [manager.imageCache imageFromDiskCacheForKey:photo.urlThumbString];
              [weakSelf.scalingImageView updateImage:thumbImage];
          }
          [manager downloadImageWithURL:[NSURL URLWithString:photo.urlImageString]
                                options:0
                               progress:^(NSInteger receivedSize, NSInteger expectedSize) {
                                   // progression tracking code
                               } completed:^(UIImage* image, NSError* error, SDImageCacheType cacheType, BOOL finished, NSURL* imageURL) {
                                   if (image) {
                                       [weakSelf updateImage:image];
                                   }
                               }];
    }];
}

- (instancetype)initWithPhoto:(id <NYTPhoto>)photo loadingView:(UIView*)loadingView notificationCenter:(NSNotificationCenter*)notificationCenter {
    return [self initWithPhoto:photo loadingView:loadingView assignLoadImage:NO notificationCenter:notificationCenter];
}

- (instancetype)initWithPhoto:(id <NYTPhoto>)photo loadingView:(UIView*)loadingView assignLoadImage:(BOOL)assingLoading notificationCenter:(NSNotificationCenter*)notificationCenter {
    self = [super initWithNibName:nil bundle:nil];

    if (self) {
        _photo = photo;

        UIImage* photoImage = photo.image ? : photo.placeholderImage;

        _scalingImageView          = [[NYTScalingImageView alloc] initWithImage:photoImage frame:CGRectZero];
        _scalingImageView.delegate = self;

        if (!photo.image) {
            [self setupLoadingView:loadingView];
        }

        if (assingLoading) {
            [self loadImageAtItem:photo];
        }

        _notificationCenter = notificationCenter;

        [self setupGestureRecognizers];
    }

    return self;
}

- (void)setupLoadingView:(UIView*)loadingView {
    self.loadingView = loadingView;
    if (!loadingView) {
        UIActivityIndicatorView* activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        [activityIndicator startAnimating];
        self.loadingView = activityIndicator;
    }
}

- (void)photoImageUpdatedWithNotification:(NSNotification*)notification {
    id <NYTPhoto> photo = notification.object;
    if ([photo conformsToProtocol:@protocol(NYTPhoto)] && [photo isEqual:self.photo]) {
        [self updateImage:photo.image];
    }
}

- (void)updateImage:(UIImage*)image {
    [self.scalingImageView updateImage:image];

    if (image) {
        [self.loadingView removeFromSuperview];
        self.loadingView = nil;
    }
}

#pragma mark - Gesture Recognizers

- (void)setupGestureRecognizers {
    self.doubleTapGestureRecognizer                      = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didDoubleTapWithGestureRecognizer:)];
    self.doubleTapGestureRecognizer.numberOfTapsRequired = 2;
    self.doubleTapGestureRecognizer.delegate             = self;

    self.longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(didLongPressWithGestureRecognizer:)];
}

- (void)didDoubleTapWithGestureRecognizer:(UITapGestureRecognizer*)recognizer {
    CGPoint pointInView = [recognizer locationInView:self.scalingImageView.imageView];

    CGFloat newZoomScale = self.scalingImageView.maximumZoomScale;

    if (self.scalingImageView.zoomScale >= self.scalingImageView.maximumZoomScale) {
        newZoomScale = self.scalingImageView.minimumZoomScale;
    }

    CGSize scrollViewSize = self.scalingImageView.bounds.size;

    CGFloat width   = scrollViewSize.width / newZoomScale;
    CGFloat height  = scrollViewSize.height / newZoomScale;
    CGFloat originX = pointInView.x - (width / 2.0);
    CGFloat originY = pointInView.y - (height / 2.0);

    CGRect rectToZoomTo = CGRectMake(originX, originY, width, height);

    [self.scalingImageView zoomToRect:rectToZoomTo animated:YES];
}

- (void)didLongPressWithGestureRecognizer:(UILongPressGestureRecognizer*)recognizer {
    if ([self.delegate respondsToSelector:@selector(photoViewController:didLongPressWithGestureRecognizer:)]) {
        if (recognizer.state == UIGestureRecognizerStateBegan) {
            [self.delegate photoViewController:self didLongPressWithGestureRecognizer:recognizer];
        }
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer*)gestureRecognizer shouldReceiveTouch:(UITouch*)touch {
    /* Fixbug khi tap vao label thi zoom ảnh */
    if ([touch.view isKindOfClass:[UILabel class]]) {
        return NO;     // ignore the touch
    }
    return YES; // handle the touch
}

#pragma mark - UIScrollViewDelegate

- (UIView*)viewForZoomingInScrollView:(UIScrollView*)scrollView {
    return self.scalingImageView.imageView;
}

- (void)scrollViewWillBeginZooming:(UIScrollView*)scrollView withView:(UIView*)view {
    scrollView.panGestureRecognizer.enabled = YES;
}

- (void)scrollViewDidEndZooming:(UIScrollView*)scrollView withView:(UIView*)view atScale:(CGFloat)scale {
    // There is a bug, especially prevalent on iPhone 6 Plus, that causes zooming to render all other gesture recognizers ineffective.
    // This bug is fixed by disabling the pan gesture recognizer of the scroll view when it is not needed.
    if (scrollView.zoomScale == scrollView.minimumZoomScale) {
        scrollView.panGestureRecognizer.enabled = NO;
    }
}

- (void)scrollViewDidZoom:(UIScrollView*)scrollView {
    // The scroll view has zoomed, so we need to re-center the contents
    [self.scalingImageView centerScrollViewContents];
}

@end
