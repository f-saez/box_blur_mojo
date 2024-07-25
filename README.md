# box blur mojo
## Box filtering approximation of Gaussian convolution

The purpose of this filter is not to be a precise approximation of a Gaussian blur.
First, box filtering isn't really the best algorithm for this.
Then because the aim is simply to blur images. Nothing more than a visual blur.

Blur is usually achieved using a convolution kernel and, in general, if you want a blurrier image, you have to use a bigger kernel, which means a longer processing time.
It is possible to use a smaller kernel and make multiple passes, but again, multiple passes lengthen processing time.

But if an image is really blurred, then it contains very little detail and you probably don't need to process every pixel of the original image.
Ideally, you can use 1 pixel out of 4 or 1 pixel out of 8, ... of the original image.
This way, you can have the same processing time, regardless of the level of blur.

### So what's the catch ?
Basically, you can't really take advantage of SIMD. SIMD has been created to process contiguous data and we're going to work on non-contiguous data. 
For smaller blur or smaller images, we could use another algorithm.

So, it may be efficient for high level of blur and for big images, but if you want to blur thumbnails, it's not the best choice

## Enough talk, how to use it ?

There are two versions : a mono-thread and a multi-thread
```
def main():

    var src = Image.from_ppm(Path("test/Octopus.ppm")) 
    var dst = Image.new(src.get_width(), src.get_height())
    var sigma = 8

    # mono thread
    _ = boxblur.boxblur(src, dst, sigma)
    _ = dst.to_ppm("mono_boxblur_"+str(sigma)+".ppm")

    # multi-thread
    _ = boxblur.boxblur_par(src, dst, sigma,8) # 8 => 8 threads
    _ = dst.to_ppm("multi_boxblur_"+str(sigma)+".ppm")
```

I'm not sure I've done the multi-thread one in a clean "Mojo-ish" way, but it shouldn't explode in your face

It is not supposed to be used "as-is", but will be integrated in Blend2D soon.






