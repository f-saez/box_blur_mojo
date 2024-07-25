
from ppm import Image
from pathlib import Path
from collections import InlineList
from testing import assert_true

import boxblur

fn almost_equal(a : Image, b : Image) -> Bool:
    """
        Comparing two images, one reference and one created by the same library
        but on a different architecture or a different version or with a different codec could result in
        small and invisible differences
        So to prevent a bunch of troubles, I choose to allow a small percentage of differences.
        something like 5% of the pixels could have a 4% difference.
    """
    var result = False
    var w = a.get_width()
    var h = a.get_height()
    var num_pixels = w*h
    var num_diff = 0
    if w==b.get_width() and h==b.get_height() and a.get_stride()==b.get_stride():
        # a dumb way to do that, but who cares ?
        for y in range(h):
            var idx = y*a.get_stride()
            for x in range(w):
                var delta = abs(a.pixels[idx].cast[DType.int32]() - b.pixels[idx].cast[DType.int32]())
                if delta>=10:
                    num_diff += 1
                else:
                    delta = abs(a.pixels[idx+1].cast[DType.int32]() - b.pixels[idx+1].cast[DType.int32]())
                    if delta>10:
                        num_diff += 1
                    else:                                    
                        delta = abs(a.pixels[idx+2].cast[DType.int32]() - b.pixels[idx+2].cast[DType.int32]())                            
                        if delta>10:
                            num_diff += 1
                        else:                                    
                            delta = abs(a.pixels[idx+3].cast[DType.int32]() - b.pixels[idx+3].cast[DType.int32]())                                
                            if delta>10:
                                num_diff += 1                                                                            
        result = Float32(num_diff) / Float32(num_pixels) <= 0.05
    return result


def validation():
    var src = Image.from_ppm(Path("validation/Octopus.ppm")) 
    var dst_ref = Image.new(src.get_width(), src.get_height())
    var dst_simd = Image.new(src.get_width(), src.get_height())
    var dst_par = Image.new(src.get_width(), src.get_height())
    var sigmas = InlineList[Int](2,4,8,16,24)

    for sigma in sigmas:
        boxblur.boxblur_scalar(src, dst_ref, sigma[])
        var r = boxblur.boxblur(src, dst_simd, sigma[])
        assert_true(r)
        assert_true( almost_equal(dst_ref, dst_simd) )
        r = boxblur.boxblur_par(src, dst_par, sigma[],2)
        assert_true(r)
        assert_true( almost_equal(dst_ref, dst_par) )
        r = boxblur.boxblur_par(src, dst_par, sigma[],4)
        assert_true(r)
        assert_true( almost_equal(dst_ref, dst_par) )
        r = boxblur.boxblur_par(src, dst_par, sigma[],8)
        assert_true(r)
        assert_true( almost_equal(dst_ref, dst_par) )
        r = boxblur.boxblur_par(src, dst_par, sigma[],16)
        assert_true(r)
        assert_true( almost_equal(dst_ref, dst_par) )

