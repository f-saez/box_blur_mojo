from pathlib import Path
from testing import assert_equal
from memory import AddressSpace
from time import now


@value
struct Image:
    var pixels      : DTypePointer[DType.uint8, AddressSpace.GENERIC]
    var _num_pixels : Int    
    var _width      : Int
    var _height     : Int
    var _stride     : Int
    var _bpp        : Int
    
    fn __init__(inout self, pixels : DTypePointer[DType.uint8, AddressSpace.GENERIC], width : Int, height : Int):
        self.pixels = pixels
        self._width  = width
        self._height = height
        self._num_pixels = width*height
        self._bpp    = 4
        self._stride = width*self._bpp

    @staticmethod
    fn new(width : Int, height : Int) -> Self:
        var pixels = DTypePointer[DType.uint8, AddressSpace.GENERIC]().alloc(width*height*4, alignment=32) # alignment on 256 bits, not sure it is usefull 
        return Self(pixels, width, height)

    fn to_ppm(self,filename : Path ) raises -> Bool:
        var w = self.get_width()
        var h = self.get_height()
        var header = "P6\n"+String(w)+" "+String(h)+"\n255\n"  
        var bytes = List[UInt8](capacity=self.get_width()*self.get_height()*3)
        
        for adr in range(self._num_pixels): 
            var rgba = self.pixels.load[width=4](adr*self._bpp)
            bytes.append( rgba[0] )
            bytes.append( rgba[1] )
            bytes.append( rgba[2] )
        var t = len(bytes)
        bytes.append(bytes[t-1]) # write remove the last byte of everything, string or not, so ...
        with open(filename, "wb") as f:
            f.write(header)
            f.write(bytes)  # expect a string but is happy to accept a bunch of bytes (why ?), except it just eat the last byte thinking it's a zero-terminal string        
        return True

    @staticmethod
    fn from_ppm(filename : Path) raises -> Self:
        """
        Only PPM P6 => RGB <=> 3xUInt8
        PPM could contains a comment and the comment must begin with #
        here we see a point of failure because we could use a comment starting with a digit
        and it will break the with/height detection
        a good pratice'll have been to put the mandatory fields (width/height/maxval) right after the magic byte 
        and the facultative comment at the end of the header.
        """        
        var width = 0
        var height = 0
        var idx = 0

        if filename.is_file():
            var header = List[UInt8]()
            with open(filename, "rb") as f:
                header = f.read_bytes(512)
            if header[0] == 0x50 and header[1] == 0x36:  # => P6 
                idx = 2
                for _ in range(idx, header.size):  # entering a comment area that may not exist
                    if header[idx] == 0x0A:
                        if header[idx+1]!=ord("#"):  # it's not a comment                        
                            break
                    idx += 1
                var idx_start = idx
                for _ in range(idx, header.size):  # the width
                    if header[idx] == 0x20:                        
                        idx += 1
                        width = atol( String(header[idx_start:idx]) )
                        break
                    idx += 1
                idx_start = idx
                for _ in range(idx, header.size): # the height
                    if header[idx] == 0x0A:
                        idx += 1
                        height = atol( String(header[idx_start:idx]) )
                        break
                    idx += 1
                for _ in range(idx, header.size):  # MAXVAL. I don't care because I only use Uint8 
                    if header[idx] == 0x0A:
                        idx += 1 
                        break
                    idx += 1                    

        var result = Self.new(width,height)
        if width>0 and height>0:
            var bytes = List[UInt8](capacity=width*height*3)
            with open(filename, "rb") as f:
                bytes = f.read_bytes()            
            if bytes.size>=width*height*3:
                for idx1 in range(0,result.get_num_bytes(),4):
                    result.pixels[idx1]   = bytes[idx]
                    result.pixels[idx1+1] = bytes[idx+1]
                    result.pixels[idx1+2] = bytes[idx+2]
                    result.pixels[idx1+3] = 255
                    idx  += 3
            
        return result
    
    fn __del__(owned self):
        self.pixels.free()

    @always_inline
    fn get_num_bytes(self) -> Int:
        return self._num_pixels*self._bpp

    @always_inline
    fn get_width(self) -> Int:
        return self._width
    
    @always_inline
    fn get_height(self) -> Int:
        return self._height

    @always_inline
    fn get_stride(self) -> Int:
        return self._stride

    @always_inline
    fn get_num_channels(self) -> Int:
        return 4

    @always_inline
    fn __calc_adr__(self,x : Int, y : Int) -> Int:
        """
            return the adress of a pixel located at (x,y)
            doesn't check if x or y are off-limit.
        """
        return x*self._bpp+y*self._stride  # TODO need to clamp adr

    @always_inline
    fn get_at(self, x : Int, y : Int) -> (UInt8, UInt8, UInt8, UInt8):
        """
            return 4 uint8 of a pixel located at (x,y).
        """
        var ptr = self.get_SIMD_at[4](x,y)
        var r = ptr[0]
        var g = ptr[1]
        var b = ptr[2]
        var a = ptr[3]
        return (r,g,b,a)
    
    @always_inline
    fn get_SIMD_at[count:Int](self, x : Int, y : Int) -> SIMD[DType.uint8,count]:
        """
            return [count] uint8 of one or more pixel located at (x,y).
            if count==4 => return the pixel at (x,y)
            if count==8 => return the pixel at (x,y) and the pixel at (x+1,y).
            doesn't make sense to use anything else thant 4 or 8, at least for now
            doesn't check if x or y are off-limit.
        """
        var adr = self.__calc_adr__(x,y)
        return self.pixels.load[width=count](adr)
    
    @always_inline
    fn write_SIMD_at[count:Int](self, x : Int, y : Int, v : SIMD[DType.uint8,count]):
        """
            write [count] uint8 of one or more pixel located at (x,y).
            if count==4 => write the pixel at (x,y)
            if count==8 => write the pixel at (x,y) and the pixel at (x+1,y).
            doesn't make sense to use anything else thant 4 or 8, at least for now
            doesn't check if x or y are off-limit.
        """
        var adr = self.__calc_adr__(x,y)
        return self.pixels.store[width=count](adr,v)

    @staticmethod
    fn validation() raises :      
        var filename = Path("test/result.ppm") # this file have a comment
        var ppm = Image.from_ppm(filename)
        assert_equal(ppm.get_width(),320)
        assert_equal(ppm.get_height(),214)
        assert_equal(ppm.get_num_channels(),4)
        var y = 0
        var x = 0
        # first pixel is red
        var rgba = ppm.get_at(x,y)
        assert_equal(rgba[0],255)
        assert_equal(rgba[1],0)
        assert_equal(rgba[2],0)
        assert_equal(rgba[3],255)

        # second pixel is green
        x = 1
        rgba = ppm.get_at(x,y)
        assert_equal(rgba[0],0)
        assert_equal(rgba[1],255)
        assert_equal(rgba[2],0)
        assert_equal(rgba[3],255)

        # third pixel is blue
        x = 2
        rgba = ppm.get_at(x,y)
        assert_equal(rgba[0],0)
        assert_equal(rgba[1],0)
        assert_equal(rgba[2],255)
        assert_equal(rgba[3],255)

        # fourth pixel is black
        x = 3
        rgba = ppm.get_at(x,y)
        assert_equal(rgba[0],0)
        assert_equal(rgba[1],0)
        assert_equal(rgba[2],0)
        assert_equal(rgba[3],255)

        # fifth pixel is white
        x = 4
        rgba = ppm.get_at(x,y)
        assert_equal(rgba[0],255)
        assert_equal(rgba[1],255)
        assert_equal(rgba[2],255)
        assert_equal(rgba[3],255)

        filename = Path("test/result2.ppm") # this file have no comment
        ppm = Image.from_ppm(filename)
        assert_equal(ppm.get_num_channels(),4)
        assert_equal(ppm.get_width(),298)
        assert_equal(ppm.get_height(),205)
        y = 0
        x = 0
        # first pixel is red
        rgba = ppm.get_at(x,y)
        assert_equal(rgba[0],255)
        assert_equal(rgba[1],0)
        assert_equal(rgba[2],0)
        assert_equal(rgba[3],255)

        # second pixel is green
        x = 1
        rgba = ppm.get_at(x,y)
        assert_equal(rgba[0],0)
        assert_equal(rgba[1],255)
        assert_equal(rgba[2],0)
        assert_equal(rgba[3],255)

        # third pixel is blue
        x = 2
        rgba = ppm.get_at(x,y)
        assert_equal(rgba[0],0)
        assert_equal(rgba[1],0)
        assert_equal(rgba[2],255)
        assert_equal(rgba[3],255)

        # fourth pixel is black
        x = 3
        rgba = ppm.get_at(x,y)
        assert_equal(rgba[0],0)
        assert_equal(rgba[1],0)
        assert_equal(rgba[2],0)
        assert_equal(rgba[3],255)

        # fifth pixel is white
        x = 4 
        rgba = ppm.get_at(x,y)
        #assert_equal(rgba[0],255)
        assert_equal(rgba[1],255)
        assert_equal(rgba[2],255)
        assert_equal(rgba[3],255)


  

