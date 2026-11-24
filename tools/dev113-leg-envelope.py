"""Read-only RGBA PNG alpha audit; no image generation or editing."""
import json, pathlib, struct, zlib
path = pathlib.Path('E:/GALUMU/game/assets/art/pixel_v03/rider_atlas.png')
raw = path.read_bytes(); assert raw[:8] == b'\x89PNG\r\n\x1a\n'
at = 8; compressed = bytearray()
while at < len(raw):
    n = struct.unpack('>I',raw[at:at+4])[0]; tag=raw[at+4:at+8]; data=raw[at+8:at+8+n]; at+=12+n
    if tag == b'IHDR': width,height,depth,kind,_,_,interlace=struct.unpack('>IIBBBBB',data)
    elif tag == b'IDAT': compressed.extend(data)
assert (depth,kind,interlace)==(8,6,0)
data=zlib.decompress(compressed); stride=width*4; rows=[]; previous=bytearray(stride); at=0
def paeth(a,b,c):
    p=a+b-c; pa,pb,pc=abs(p-a),abs(p-b),abs(p-c)
    return a if pa<=pb and pa<=pc else (b if pb<=pc else c)
for y in range(height):
    mode=data[at];at+=1;row=bytearray(data[at:at+stride]);at+=stride
    for x in range(stride):
        a=row[x-4] if x>=4 else 0;b=previous[x];c=previous[x-4] if x>=4 else 0
        value=(0,a,b,(a+b)//2,paeth(a,b,c))[mode]
        row[x]=(row[x]+value)&255
    rows.append(row);previous=row
def hull(points):
    def cross(o,a,b): return (a[0]-o[0])*(b[1]-o[1])-(a[1]-o[1])*(b[0]-o[0])
    ordered=sorted(set(points));lo=[];hi=[]
    for p in ordered:
        while len(lo)>=2 and cross(lo[-2],lo[-1],p)<=0:lo.pop()
        lo.append(p)
    for p in reversed(ordered):
        while len(hi)>=2 and cross(hi[-2],hi[-1],p)<=0:hi.pop()
        hi.append(p)
    return lo[:-1]+hi[:-1]
result={}
for name,box in [('thigh',(687,633,204,117)),('boot',(744,736,148,197))]:
    x0,y0,w,h=box;points=[];count=0
    for y in range(y0,y0+h):
        active=[x for x in range(x0,x0+w) if rows[y][x*4+3]>=16]
        count+=len(active)
        if active:
            for x in [active[0],active[-1]]:points.extend([(x,y),(x+1,y),(x,y+1),(x+1,y+1)])
    result[name]={'pixels':count,'outline':hull(points)}
print(json.dumps(result,indent=2))
