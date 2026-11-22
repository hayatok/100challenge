from PIL import Image,ImageDraw,ImageFilter
import json,os,sys
parts_file,skins_root,out=sys.argv[1:4];s=2048
mask=Image.new('L',(s,s));d=ImageDraw.Draw(mask)
for part in json.load(open(parts_file)):
 for f in part['uv']:d.polygon([(u*s,(1-v)*s)for u,v in f],fill=255)
mask=mask.filter(ImageFilter.MaxFilter(9))
src=skins_root.rstrip('/\\')+'/'
for name,path,bg in [('SkinYoung',src+'mindfront_aksel_skin/Aksel_Skin_diffuse.png',(140,105,83)),('SkinElder',src+'onlytheghosts_old_eurasian_male/old_eurasian_male_diffuse.png',(140,105,83)),('SkinNormal',src+'mindfront_aksel_skin/Aksel_Skin_NRM.png',(128,128,255)),('SkinSpecular',src+'mindfront_aksel_skin/Aksel_Skin_SPEC.png',(0,0,0))]:
 im=Image.open(path).convert('RGB').resize((s,s),Image.Resampling.LANCZOS);Image.composite(im,Image.new('RGB',(s,s),bg),mask).save(out+'/'+name+'.png')
