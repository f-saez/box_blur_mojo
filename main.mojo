
from ppm import Image
from pathlib import Path
from time import now
from collections import InlineList
from algorithm import parallelize
import validation

import boxblur

def benchmark():
    var src = Image.from_ppm(Path("validation/Octopus.ppm")) 
    var dst = Image.new(src.get_width(), src.get_height())
    var sigma = 14
    var tocs = List[Float64]()
    for _ in range(500):
        var tic = now()
        _ = boxblur.boxblur_scalar(src, dst, sigma)
        tocs.append( Float64(now() - tic) / 1e6)
    var mean:Float64 = 0
    for toc in tocs:
        mean += toc[]
    mean /= Float64(tocs.size)
    print("mono-thread/scalar : mean : ", mean," ms")
    
    tocs.clear()
    for _ in range(500):
        var tic = now()
        _ = boxblur.boxblur(src, dst, sigma)
        tocs.append( Float64(now() - tic) / 1e6)
    mean = 0
    for toc in tocs:
        mean += toc[]
    mean /= Float64(tocs.size)
    print("mono-thread/simd mean : ", mean," ms")

    tocs.clear()
    for _ in range(500):
        var tic = now()
        _ = boxblur.boxblur_par(src, dst, sigma,8)
        tocs.append( Float64(now() - tic) / 1e6)
    mean = 0
    for toc in tocs:
        mean += toc[]
    mean /= Float64(tocs.size)
    print("8 threads/simd mean : ", mean," ms")


def main():
    validation.validation()
    
    var src = Image.from_ppm(Path("validation/Octopus.ppm")) 
    var dst = Image.new(src.get_width(), src.get_height())
    var sigmas = InlineList[Int](2,4,8,16,24)

    print("monothread")
    for sigma in sigmas:
        var tic = now()
        _ = boxblur.boxblur(src, dst, sigma[])
        print("Sigma : ",sigma[],"  ",Float64(now() - tic) / 1e6," ms")
        _ = dst.to_ppm("mono_boxblur_"+str(sigma[])+".ppm")

    print("multi-thread")
    for sigma in sigmas:
        var tic = now()
        _ = boxblur.boxblur_par(src, dst, sigma[],8)
        print("Sigma : ",sigma[],"  ",Float64(now() - tic) / 1e6," ms")
        _ = dst.to_ppm("multi_boxblur_"+str(sigma[])+".ppm")        


