
from testing import assert_almost_equal, assert_equal
from ppm import Image
from pathlib import Path
from math import sqrt
from time import now
from algorithm import parallelize

alias K:Int = 3 # do not touch :-)

# deprecated, will be removed
@always_inline
fn clamp_(limit : Int, n : Int) -> Int:
    if n < 0:
        return -1 - n # Reflect over n = -1/2. 
    elif n >= limit:
        return 2 * limit - 1 - n # Reflect over n = N - 1/2.
    else:
        return n

@always_inline
@parameter
fn clamp1(x : Int, limit : Int, a : Int, b : Int) -> Int:
    if x < 0:
        return a # Reflect over n = -1/2. 
    elif x >= limit:
        return b # Reflect over n = N - 1/2.
    else:
        return x


fn box_filter_a(src : DTypePointer[DType.uint8, AddressSpace.GENERIC], dst : DTypePointer[DType.float32, AddressSpace.GENERIC], z : Int, width : Int, radius : Int) -> Bool:
    var result = width>0 and radius>0
    if result:        
        # Initialize the filter on the left boundary by directly computing
        # dest(0) = accum = sum_{n=-r}^r src(n). 
        var accum_r:Float32 = 0
        var accum_g:Float32 = 0
        var accum_b:Float32 = 0
        var accum_a:Float32 = 0
        var coef:Float32 = 1 / 255
        var radius1 = -radius-1
        for x in range(-radius, radius+1):
            var idx = clamp_(width, x) * z
            accum_r += src[idx].cast[DType.float32]() * coef
            accum_g += src[idx+1].cast[DType.float32]() * coef
            accum_b += src[idx+2].cast[DType.float32]() * coef
            accum_a += src[idx+3].cast[DType.float32]() * coef
        
        var idx = 0
        dst[idx  ] = accum_r
        dst[idx+1] = accum_g
        dst[idx+2] = accum_b
        dst[idx+3] = accum_a

        # Filter the interior samples. 
        for x in range(1,width):
            # Update accum: add sample src(n + r) and remove src(n - r - 1). 
            var idx1 = clamp_(width, x+radius) * z
            var idx2 = clamp_(width, x+radius1)* z # width, x-radius-1) * z
            # a basic sliding window   
            accum_r += (src[idx1  ].cast[DType.float32]() - src[idx2  ].cast[DType.float32]()) * coef
            accum_g += (src[idx1+1].cast[DType.float32]() - src[idx2+1].cast[DType.float32]()) * coef
            accum_b += (src[idx1+2].cast[DType.float32]() - src[idx2+2].cast[DType.float32]()) * coef
            accum_a += (src[idx1+3].cast[DType.float32]() - src[idx2+3].cast[DType.float32]()) * coef

            idx += 4
            dst[idx    ] = accum_r
            dst[idx + 1] = accum_g
            dst[idx + 2] = accum_b
            dst[idx + 3] = accum_a
           
    return result

fn box_filter_b(src : DTypePointer[DType.float32, AddressSpace.GENERIC], dst : DTypePointer[DType.float32, AddressSpace.GENERIC], width : Int, radius : Int) -> Bool:
    var result = width>0 and radius>0 
   
    if result:        
        # Initialize the filter on the left boundary by directly computing
        # dest(0) = accum = sum_{n=-r}^r src(n). 
        var accum_r:Float32 = 0
        var accum_g:Float32 = 0
        var accum_b:Float32 = 0
        var accum_a:Float32 = 0
        var radius1 = -radius-1

        for n in range(-radius, radius+1):
            var idx = clamp_(width, n) << 2
            accum_r += src[idx]
            accum_g += src[idx+1]
            accum_b += src[idx+2]
            accum_a += src[idx+3]

        var idx = 0
        dst[idx ] = accum_r
        dst[idx+1] = accum_g
        dst[idx+2] = accum_b
        dst[idx+3] = accum_a
        
        # Filter the interior samples. 
        for x in range(1,width):
            # Update accum: add sample src(n + r) and remove src(n - r - 1). 
            var idx1 = clamp_(width, x+radius) << 2 
            var idx2 = clamp_(width, x+radius1) << 2 
            accum_r += src[idx1  ] - src[idx2  ]
            accum_g += src[idx1+1] - src[idx2+1]
            accum_b += src[idx1+2] - src[idx2+2]
            accum_a += src[idx1+3] - src[idx2+3]
            idx += 4
            dst[idx    ] = accum_r
            dst[idx + 1] = accum_g
            dst[idx + 2] = accum_b
            dst[idx + 3] = accum_a
            
    return result

fn box_filter_c(src : DTypePointer[DType.float32, AddressSpace.GENERIC], dst : DTypePointer[DType.uint8, AddressSpace.GENERIC], z : Int, maxi : Int, radius : Int, scale : Float32) -> Bool:
    var result = maxi>0 and radius>0 
   
    if result:        
        # Initialize the filter on the left boundary by directly computing
        # dest(0) = accum = sum_{n=-r}^r src(n). 
        var accum_r:Float32 = 0
        var accum_g:Float32 = 0
        var accum_b:Float32 = 0
        var accum_a:Float32 = 0
        var radius1 = -radius-1
        for n in range(-radius, radius+1):
            var idx = clamp_(maxi, n) << 2 
            accum_r += src[idx]
            accum_g += src[idx+1]
            accum_b += src[idx+2]
            accum_a += src[idx+3]

        var idx = 0
        dst[idx  ] = byte(accum_r, scale)
        dst[idx+1] = byte(accum_g, scale)
        dst[idx+2] = byte(accum_b, scale)
        dst[idx+3] = byte(accum_a, scale)

        # Filter the interior samples. 
        for n in range(1,maxi):
            # Update accum: add sample src(n + r) and remove src(n - r - 1). 
            var idx1 = clamp_(maxi, n+radius) << 2
            var idx2 = clamp_(maxi, n+radius1) << 2
            accum_r += src[idx1  ] - src[idx2  ]
            accum_g += src[idx1+1] - src[idx2+1]
            accum_b += src[idx1+2] - src[idx2+2]
            accum_a += src[idx1+3] - src[idx2+3]            
            idx += z # z=4 => x += 1 or z=stride => y += 1
            dst[idx    ] = byte(accum_r, scale)
            dst[idx + 1] = byte(accum_g, scale)
            dst[idx + 2] = byte(accum_b, scale)
            dst[idx + 3] = byte(accum_a, scale)
            
    return result

@always_inline
@parameter
fn byte(x : Float32, scale : Float32) -> UInt8:
    var v = x * scale
    if v>=255:
        return 255
    elif v<0:
        return 0
    else:
        return v.cast[DType.uint8]()

fn box_filter_simd_a(src : DTypePointer[DType.uint8, AddressSpace.GENERIC], dst : DTypePointer[DType.float32, AddressSpace.GENERIC], z : Int, maxi : Int, radius : Int) -> Bool:
    var result = maxi>0 and radius>0
    if result:        
        # Initialize the filter on the left boundary by directly computing
        # dest(0) = accum = sum_{n=-r}^r src(n). 
        var accum = SIMD[DType.float32,size=4](0)
        var coef = SIMD[DType.float32,size=4](1/255)
        var radius1 = -radius-1
        var adl = 2 * maxi - 1
        for x in range(-radius, radius+1):
            var i = clamp1(x, maxi, -1 - x, adl - x ) * z
            accum += src.load[width=4](i).cast[DType.float32]() * coef
        
        var idx = 0
        dst.store[width=4](idx, accum)

        # Filter the interior samples. 
        for x in range(1,maxi):
            # Update accum: add sample src(n + r) and remove src(n - r - 1). 
            var x1 = x+radius
            var x2 =  x+radius1
            var i0 = clamp1(x1, maxi, -1 - x1, adl - x1 ) * z
            var i1 = clamp1(x2, maxi, -1 - x2, adl - x2 ) * z
            # a basic sliding window
            var a = src.load[width=4](i0).cast[DType.int32]() - src.load[width=4](i1).cast[DType.int32]()
            accum += a.cast[DType.float32]() * coef
            idx += 4
            dst.store[width=4](idx, accum)
           
    return result

fn box_filter_simd_b(src : DTypePointer[DType.float32, AddressSpace.GENERIC], dst : DTypePointer[DType.float32, AddressSpace.GENERIC], width : Int, radius : Int) -> Bool:
    var result = width>0 and radius>0 
   
    if result:        
        # Initialize the filter on the left boundary by directly computing
        # dest(0) = accum = sum_{n=-r}^r src(n). 
        var accum = SIMD[DType.float32,size=4](0)
        var radius1 = -radius-1
        var adl = 2 * width - 1
        for x in range(-radius, radius+1):
            var idx = clamp1(x, width, -1 - x, adl - x ) <<2 
            accum += src.load[width=4](idx)

        var idx = 0
        dst.store[width=4](idx, accum)
        
        # Filter the interior samples. 
        for x in range(1,width):
            # Update accum: add sample src(n + r) and remove src(n - r - 1). 
            var x1 = x+radius
            var x2 =  x+radius1
            var i0 = clamp1(x1, width, -1 - x1, adl - x1 ) <<2
            var i1 = clamp1(x2, width, -1 - x2, adl - x2 ) <<2
            accum += src.load[width=4](i0) - src.load[width=4](i1)
            idx += 4
            dst.store[width=4](idx, accum)
            
    return result

fn box_filter_simd_c(src : DTypePointer[DType.float32, AddressSpace.GENERIC], dst : DTypePointer[DType.uint8, AddressSpace.GENERIC], z : Int, width : Int, radius : Int, scale : SIMD[DType.float32,size=4]) -> Bool:
    var result = width>0 and radius>0 
    if result:        
        var zero = SIMD[DType.int32,size=4](0)
        var two55 = SIMD[DType.int32,size=4](255)
        var radius1 = -radius-1
        var adl = 2 * width - 1
        # Initialize the filter on the left boundary by directly computing
        # dest(0) = accum = sum_{n=-r}^r src(n). 
        var accum = SIMD[DType.float32,size=4](0)
        for x in range(-radius, radius+1):
            var idx = clamp1(x, width, -1 - x, adl - x ) <<2 
            accum += src.load[width=4](idx)

        var idx = 0
        var a = (accum*scale).cast[DType.int32]().clamp(zero,two55)
        dst.store[width=4](idx, a.cast[DType.uint8]())

        # Filter the interior samples. 
        for x in range(1,width):
            # Update accum: add sample src(n + r) and remove src(n - r - 1). 
            var x1 = x+radius
            var x2 =  x+radius1
            var i0 = clamp1(x1, width, -1 - x1, adl - x1 ) <<2
            var i1 = clamp1(x2, width, -1 - x2, adl - x2 ) <<2
            accum += src.load[width=4](i0) - src.load[width=4](i1)   
            idx += z
            a = (accum*scale).cast[DType.int32]().clamp(zero,two55)
            dst.store[width=4](idx, a.cast[DType.uint8]())
            
    return result


fn boxblur_scalar(src : Image, dst : Image, sigma : Int):
    var size_buffer = src.get_width()
    if src.get_height()>size_buffer:
        size_buffer = src.get_height()
    size_buffer *= 4

    var buffer1 = DTypePointer[DType.float32, AddressSpace.GENERIC]().alloc(size_buffer)
    var buffer2 = DTypePointer[DType.float32, AddressSpace.GENERIC]().alloc(size_buffer)
    var idx = 0
    var width = Int(src.get_width())
    var height = Int(src.get_height())
    var stride = Int(src.get_stride())
    # Compute the box radius according to Wells' formula. 

    var s = Float32(12 * sigma * sigma)
    var radius = Int((0.5 * sqrt(s / K + 1.0)).cast[DType.int32]().value)
    var scale = 1.0 / pow(2*radius + 1, K) * 255.0
      
    for _ in range(src.get_height()):
        var ptr_src = src.pixels.offset(idx)
        var ptr_dst = dst.pixels.offset(idx)     
        _ = box_filter_a(ptr_src, buffer1, 4, width, radius)
        _ = box_filter_b(buffer1, buffer2, width, radius)
        _ = box_filter_c(buffer2, ptr_dst, 4, width, radius, scale)  
        idx += src.get_stride()
    
    idx = 0
    for _ in range(src.get_width()):
        var ptr_dst = dst.pixels.offset(idx)
        _ = box_filter_a(ptr_dst, buffer1, stride, height, radius)
        _ = box_filter_b(buffer1, buffer2, height, radius)
        _ = box_filter_c(buffer2, ptr_dst, stride, height, radius, scale)
        idx += 4

    buffer1.free()
    buffer2.free()
    
fn boxblur(src : Image, dst : Image, sigma : Int) -> Bool:
    # Compute the box radius according to Wells' formula. 
    var s = Float32(12 * sigma * sigma)
    var radius = Int((0.5 * sqrt(s / K + 1.0)).cast[DType.int32]().value)
    var scale = SIMD[DType.float32,4](1.0 / pow(2*radius + 1, K) * 255.0)

    var width = Int(src.get_width())
    var height = Int(src.get_height())

    # it doesn't make sense to have a radius wider than the width or the height of the image
    var result = radius<width and radius<height
    if result:
        var stride = Int(src.get_stride())

        var size_buffer = width
        if height>size_buffer:
            size_buffer = height
        size_buffer *= 4

        var buffer1 = DTypePointer[DType.float32, AddressSpace.GENERIC]().alloc(size_buffer)
        var buffer2 = DTypePointer[DType.float32, AddressSpace.GENERIC]().alloc(size_buffer)
        var idx = 0

        for _ in range(src.get_height()):
            var ptr_src = src.pixels.offset(idx)
            var ptr_dst = dst.pixels.offset(idx)     
            _ = box_filter_simd_a(ptr_src, buffer1, 4, width, radius)
            _ = box_filter_simd_b(buffer1, buffer2, width, radius)
            _ = box_filter_simd_c(buffer2, ptr_dst, 4, width, radius, scale)  
            idx += src.get_stride()

        idx = 0
        for _ in range(src.get_width()):
            var ptr_dst = dst.pixels.offset(idx)
            _ = box_filter_simd_a(ptr_dst, buffer1, stride, height, radius)
            _ = box_filter_simd_b(buffer1, buffer2, height, radius)
            _ = box_filter_simd_c(buffer2, ptr_dst, stride, height, radius, scale)
            idx += 4

        buffer1.free()
        buffer2.free()
    return result

fn boxblur_par(src : Image, dst : Image, sigma : Int, num_threads : Int) -> Bool:
    # Compute the box radius according to Wells' formula. 
    var s = Float32(12 * sigma * sigma)
    var radius = Int((0.5 * sqrt(s / K + 1.0)).cast[DType.int32]().value)
    var scale = SIMD[DType.float32,4](1.0 / pow(2*radius + 1, K) * 255.0)

    var width = Int(src.get_width())
    var height = Int(src.get_height())
    
    # it doesn't make sense to have a radius wider than the width or the height of the image
    var result = radius<width and radius<height
    if result:
        var stride = Int(src.get_stride())

        var size_buffer = width
        if height>size_buffer:
            size_buffer = height
        size_buffer *= 4

        @parameter
        fn process_y(y:Int): 
            var idx = y * stride
            var ptr_src = src.pixels.offset(idx)
            var ptr_dst = dst.pixels.offset(idx)
            var buffer1 = DTypePointer[DType.float32, AddressSpace.GENERIC]().alloc(size_buffer)
            var buffer2 = DTypePointer[DType.float32, AddressSpace.GENERIC]().alloc(size_buffer)
            _ = box_filter_simd_a(ptr_src, buffer1, 4, width, radius)
            _ = box_filter_simd_b(buffer1, buffer2, width, radius)
            _ = box_filter_simd_c(buffer2, ptr_dst, 4, width, radius, scale) 
            buffer1.free()
            buffer2.free()

        @parameter
        fn process_x(x:Int): 
            var idx = x * 4
            var ptr_dst = dst.pixels.offset(idx)
            var buffer1 = DTypePointer[DType.float32, AddressSpace.GENERIC]().alloc(size_buffer)
            var buffer2 = DTypePointer[DType.float32, AddressSpace.GENERIC]().alloc(size_buffer)
            _ = box_filter_simd_a(ptr_dst, buffer1, stride, height, radius)
            _ = box_filter_simd_b(buffer1, buffer2, height, radius)
            _ = box_filter_simd_c(buffer2, ptr_dst, stride, height, radius, scale)
            buffer1.free()
            buffer2.free()

        parallelize[process_y](height,num_threads)
        parallelize[process_x](width,num_threads)

    return result