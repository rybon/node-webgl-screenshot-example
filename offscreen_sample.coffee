
# The required node modules
THREE = require('three')
PNG   = require('pngjs').PNG
WebGL = require('node-webgl')
fs    = require('fs')

document              = WebGL.document()
requestAnimationFrame = document.requestAnimationFrame

# Parameters (the missing one is the camera position, see below)
width  = 800
height = 600
path   = 'out.png'
png    = new PNG({ width: width, height: height })

canvas = document.createElement('three-canvas', width, height)
gl     = canvas.getContext('experimental-webgl')

gl.getShaderPrecisionFormat = () =>
    precision: 'mediump'

parentShaderSource = gl.shaderSource

gl.shaderSource = (shader, string) =>
    string = string.split('\n').filter((line) =>
        !line.startsWith('precision')
    ).join('\n')
    parentShaderSource(shader, string)

gl.viewportWidth = canvas.width
gl.viewportHeight = canvas.height

# THREE.js business starts here
scene = new THREE.Scene()
scene.background = new THREE.Color(0x000000)

# camera attributes
VIEW_ANGLE = 45
ASPECT = width / height
NEAR = 0.1
FAR  = 100

# set up camera
camera = new THREE.PerspectiveCamera(VIEW_ANGLE, ASPECT, NEAR, FAR)

scene.add(camera)
camera.position.set(0, 2, 2)
camera.lookAt(scene.position)

# mock object, not used in our test case, might be problematic for some workflow
canvas = new Object()

# The width / height we set here doesn't matter
renderer = new THREE.WebGLRenderer({
    antialias: true,
    width: 0,
    height: 0,
    canvas: canvas, # This parameter is usually not specified
    context: gl     # Use the node-webgl context for drawing offscreen
})

# add some geometry
geometry = new THREE.BoxGeometry( 1, 1, 1 )

# add a material; it has to be a ShaderMaterial with custom shaders for now
# this is a work in progress, some related link / issues / discussions
#
# https://github.com/stackgl/headless-gl/issues/26
# https://github.com/mrdoob/three.js/pull/7136
# https://github.com/mrdoob/three.js/issues/7085
material = new THREE.ShaderMaterial()
vec4 = new THREE.Vector4( 1.0, 0.0, 0.0, 1.0 ) # red

material.vertexShader = '''
void main() {
    gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );
}
'''
material.fragmentShader = '''
uniform vec4 solidColor;

void main() {
    gl_FragColor = solidColor;
}
'''
material.uniforms = { solidColor: { type: 'v4', value: vec4 } }

# Create the mesh and add it to the scene
cube     = new THREE.Mesh(geometry, material)
scene.add(cube)

# Let's create a render target object where we'll be rendering
rtTexture = new THREE.WebGLRenderTarget(
    width, height, {
        minFilter: THREE.LinearFilter,
        magFilter: THREE.NearestFilter,
        format: THREE.RGBAFormat
})

# render
renderer.render(scene, camera, rtTexture, true)

# read render texture into buffer
gl = renderer.getContext()

# create a pixel buffer of the correct size
pixels = new Uint8Array(4 * width * height)

# read back in the pixel buffer
gl.readPixels(0, 0, width, height, gl.RGBA, gl.UNSIGNED_BYTE, pixels)

# lines are vertically flipped in the FBO / need to unflip them
for j in [0...height]
    for i in [0...width]
        idx = (width * j + i) << 2

        png.data[idx]     = pixels[idx]
        png.data[idx + 1] = pixels[idx + 1]
        png.data[idx + 2] = pixels[idx + 2]
        png.data[idx + 3] = pixels[idx + 3]

# Now write the png to disk
stream = fs.createWriteStream(path)
png.pack().pipe stream

stream.on 'close', () ->
    # We're done !!
    console.log("Image written: #{ path }")
