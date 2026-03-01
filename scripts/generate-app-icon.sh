mkdir -p AppBundle/Glint.iconset
for size in 16 32 64 128 256 512 1024; do
  sips -z $size $size app-icon.png --out AppBundle/Glint.iconset/icon_${size}x${size}.png >/dev/null
  small=$((size/2))
  cp AppBundle/Glint.iconset/icon_${size}x${size}.png \
     AppBundle/Glint.iconset/icon_${small}x${small}@2x.png
done
iconutil -c icns AppBundle/Glint.iconset -o AppBundle/Glint.icns
rm -r AppBundle/Glint.iconset

