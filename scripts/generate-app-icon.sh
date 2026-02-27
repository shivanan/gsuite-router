mkdir -p AppBundle/GSuiteRouter.iconset
for size in 16 32 64 128 256 512 1024; do
  sips -z $size $size app-icon.png --out AppBundle/GSuiteRouter.iconset/icon_${size}x${size}.png >/dev/null
  small=$((size/2))
  cp AppBundle/GSuiteRouter.iconset/icon_${size}x${size}.png \
     AppBundle/GSuiteRouter.iconset/icon_${small}x${small}@2x.png
done
iconutil -c icns AppBundle/GSuiteRouter.iconset -o AppBundle/GSuiteRouter.icns
rm -r AppBundle/GSuiteRouter.iconset

