import bpy
import bmesh
import math
import os
import random
from mathutils import Vector, Matrix

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS_DIR = os.path.join(PROJECT_ROOT, "godot", "assets", "models")
TEXTURES_DIR = os.path.join(PROJECT_ROOT, "godot", "assets", "textures")
UI_DIR = os.path.join(PROJECT_ROOT, "godot", "assets", "ui")

DINO_IDS = ["trex", "raptor", "triceratops", "stego", "brachio"]
TOOLS = ["brush", "pickaxe", "detector", "camera"]
BIOMES = ["desert", "forest", "ice"]

DINO_PARAMS = {
    "trex": {"body_scale": (1.2, 0.8, 1.0), "head_scale": (0.8, 0.8, 0.8), "tail_len": 2.0, "leg_len": 1.0, "color": (0.6, 0.3, 0.1)},
    "raptor": {"body_scale": (0.8, 0.5, 0.6), "head_scale": (0.5, 0.5, 0.5), "tail_len": 1.5, "leg_len": 0.8, "color": (0.2, 0.5, 0.2)},
    "triceratops": {"body_scale": (1.3, 0.9, 0.9), "head_scale": (0.9, 0.9, 0.9), "tail_len": 1.2, "leg_len": 0.7, "color": (0.4, 0.4, 0.6)},
    "stego": {"body_scale": (1.4, 0.7, 0.8), "head_scale": (0.6, 0.6, 0.6), "tail_len": 1.8, "leg_len": 0.6, "color": (0.5, 0.5, 0.2)},
    "brachio": {"body_scale": (1.5, 0.8, 1.2), "head_scale": (0.5, 0.5, 0.5), "tail_len": 2.5, "leg_len": 1.5, "color": (0.3, 0.3, 0.5)},
}

def ensure_dirs():
    for d in (MODELS_DIR, TEXTURES_DIR, UI_DIR):
        os.makedirs(d, exist_ok=True)

def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for block in bpy.data.meshes:
        bpy.data.meshes.remove(block)
    for block in bpy.data.materials:
        bpy.data.materials.remove(block)
    for block in bpy.data.armatures:
        bpy.data.armatures.remove(block)
    for block in bpy.data.actions:
        bpy.data.actions.remove(block)
    for block in bpy.data.images:
        bpy.data.images.remove(block)

def create_material(name, base_color, roughness=0.5, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*base_color, 1.0)
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
    return mat

def add_sphere(bm, radius, location, scale=(1, 1, 1), segments=16, rings=8):
    ret = bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=radius)
    verts = ret['verts']
    bmesh.ops.scale(bm, vec=scale, verts=verts)
    bmesh.ops.translate(bm, vec=location, verts=verts)

def add_cylinder(bm, radius, depth, location, rotation=(0, 0, 0), segments=16):
    ret = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments, radius1=radius, radius2=radius, depth=depth)
    verts = ret['verts']
    if rotation != (0, 0, 0):
        mat = Matrix.Rotation(rotation[0], 3, 'X') @ Matrix.Rotation(rotation[1], 3, 'Y') @ Matrix.Rotation(rotation[2], 3, 'Z')
        bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=mat, verts=verts)
    bmesh.ops.translate(bm, vec=location, verts=verts)

def add_cube(bm, size, location, scale=(1, 1, 1)):
    ret = bmesh.ops.create_cube(bm, size=size)
    verts = ret['verts']
    bmesh.ops.scale(bm, vec=scale, verts=verts)
    bmesh.ops.translate(bm, vec=location, verts=verts)

def build_dino_mesh(dino_id):
    params = DINO_PARAMS[dino_id]
    bm = bmesh.new()
    body_scale = params["body_scale"]
    add_sphere(bm, 0.8, (0, 0, 1.0), scale=body_scale)
    head_scale = params["head_scale"]
    add_sphere(bm, 0.5, (0, 0.8, 1.6), scale=head_scale)
    add_cylinder(bm, 0.2, 0.6, (0, 0.4, 1.3), rotation=(math.radians(45), 0, 0))
    tail_len = params["tail_len"]
    add_cylinder(bm, 0.15, tail_len, (0, -0.8 - tail_len / 2, 0.8), rotation=(math.radians(-90), 0, 0))
    leg_len = params["leg_len"]
    for x in (-0.4, 0.4):
        for y in (-0.3, 0.3):
            add_cylinder(bm, 0.12, leg_len, (x, y, 0.5 - leg_len / 2), rotation=(0, 0, 0))
    add_sphere(bm, 0.08, (0.2, 1.1, 1.7), scale=(1, 1, 1))
    add_sphere(bm, 0.08, (-0.2, 1.1, 1.7), scale=(1, 1, 1))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(f"dino_{dino_id}_mesh")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(f"dino_{dino_id}", mesh)
    bpy.context.collection.objects.link(obj)
    return obj

def build_dino_armature(dino_id):
    arm_data = bpy.data.armatures.new(f"dino_{dino_id}_armature")
    arm_obj = bpy.data.objects.new(f"dino_{dino_id}_armature", arm_data)
    bpy.context.collection.objects.link(arm_obj)
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode='EDIT')
    root = arm_data.edit_bones.new("root")
    root.head = (0, 0, 0)
    root.tail = (0, 0, 0.5)
    spine = arm_data.edit_bones.new("spine")
    spine.head = (0, 0, 0.5)
    spine.tail = (0, 0, 1.5)
    spine.parent = root
    head = arm_data.edit_bones.new("head")
    head.head = (0, 0, 1.5)
    head.tail = (0, 0.8, 1.8)
    head.parent = spine
    tail = arm_data.edit_bones.new("tail")
    tail.head = (0, 0, 0.5)
    tail.tail = (0, -1.5, 0.3)
    tail.parent = root
    for name, x, y in [("leg_fl", -0.4, 0.3), ("leg_fr", 0.4, 0.3), ("leg_bl", -0.4, -0.3), ("leg_br", 0.4, -0.3)]:
        bone = arm_data.edit_bones.new(name)
        bone.head = (x, y, 0.5)
        bone.tail = (x, y, 0.0)
        bone.parent = root
    bpy.ops.object.mode_set(mode='OBJECT')
    return arm_obj

def parent_mesh_to_armature(mesh_obj, arm_obj):
    for bone in arm_obj.data.bones:
        if bone.name not in mesh_obj.vertex_groups:
            mesh_obj.vertex_groups.new(name=bone.name)
    for v in mesh_obj.data.vertices:
        co = v.co
        best_bone = None
        best_dist = float('inf')
        for bone in arm_obj.data.bones:
            head = bone.head_local
            tail = bone.tail_local
            vec = tail - head
            if vec.length == 0:
                dist = (co - head).length
            else:
                t = max(0, min(1, (co - head).dot(vec) / vec.length_squared))
                closest = head + t * vec
                dist = (co - closest).length
            if dist < best_dist:
                best_dist = dist
                best_bone = bone.name
        if best_bone:
            mesh_obj.vertex_groups[best_bone].add([v.index], 1.0, 'REPLACE')
    mod = mesh_obj.modifiers.new(name="Armature", type='ARMATURE')
    mod.object = arm_obj
    mesh_obj.parent = arm_obj

def create_dino_actions(arm_obj, dino_id):
    arm_obj.animation_data_create()
    actions = {
        "idle": {"frames": [1, 30, 60], "spine_rot": [(0, 0, 0), (0, 0.05, 0), (0, 0, 0)]},
        "walk": {"frames": [1, 15, 30], "legs": [(-0.3, 0, 0), (0.3, 0, 0), (-0.3, 0, 0)]},
        "eat": {"frames": [1, 20, 40], "head_rot": [(0, 0, 0), (0.5, 0, 0), (0, 0, 0)]},
        "roar": {"frames": [1, 15, 30], "head_rot": [(0, 0, 0), (-0.5, 0, 0), (0, 0, 0)]},
    }
    for name, data in actions.items():
        action = bpy.data.actions.new(name)
        arm_obj.animation_data.action = action
        if name == "idle":
            spine = arm_obj.pose.bones.get("spine")
            if spine:
                spine.rotation_mode = 'XYZ'
                for frame, rot in zip(data["frames"], data["spine_rot"]):
                    spine.rotation_euler = rot
                    spine.keyframe_insert(data_path="rotation_euler", frame=frame)
        elif name == "walk":
            for leg_name in ["leg_fl", "leg_fr", "leg_bl", "leg_br"]:
                leg = arm_obj.pose.bones.get(leg_name)
                if leg:
                    leg.rotation_mode = 'XYZ'
                    for frame, rot in zip(data["frames"], data["legs"]):
                        leg.rotation_euler = rot
                        leg.keyframe_insert(data_path="rotation_euler", frame=frame)
        elif name in ("eat", "roar"):
            head = arm_obj.pose.bones.get("head")
            if head:
                head.rotation_mode = 'XYZ'
                for frame, rot in zip(data["frames"], data["head_rot"]):
                    head.rotation_euler = rot
                    head.keyframe_insert(data_path="rotation_euler", frame=frame)
        track = arm_obj.animation_data.nla_tracks.new()
        track.name = name
        track.strips.new(name, int(action.frame_range[0]), action)
        arm_obj.animation_data.action = None

def export_glb(filepath, objects, animations=False):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    kwargs = dict(filepath=filepath, export_format='GLB', use_selection=True, export_apply=True, export_yup=True)
    if animations:
        kwargs.update(export_animations=True, export_nla_strips=True, export_anim_single_armature=True)
    try:
        bpy.ops.export_scene.gltf(**kwargs)
    except TypeError:
        kwargs.pop('export_anim_single_armature', None)
        kwargs.pop('export_nla_strips', None)
        bpy.ops.export_scene.gltf(**kwargs)

def render_preview(filepath):
    scene = bpy.context.scene
    try:
        scene.render.engine = 'BLENDER_EEVEE_NEXT'
    except Exception:
        scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("PreviewWorld") if not scene.world else scene.world
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.05, 0.05, 0.05, 1.0)
        bg.inputs[1].default_value = 1.0
    cam_data = bpy.data.cameras.new("PreviewCamera")
    cam_obj = bpy.data.objects.new("PreviewCamera", cam_data)
    scene.collection.objects.link(cam_obj)
    cam_obj.location = (4, -4, 3)
    direction = Vector((0, 0, 1)) - cam_obj.location
    cam_obj.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
    scene.camera = cam_obj
    light_data = bpy.data.lights.new("PreviewSun", type='SUN')
    light_obj = bpy.data.objects.new("PreviewSun", light_data)
    scene.collection.objects.link(light_obj)
    light_obj.location = (3, -3, 5)
    light_obj.rotation_euler = (math.radians(45), 0, math.radians(45))
    light_data.energy = 3.0
    scene.render.filepath = filepath
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam_obj, do_unlink=True)
    bpy.data.objects.remove(light_obj, do_unlink=True)

def make_dino_skin(dino_id):
    clear_scene()
    mesh_obj = build_dino_mesh(dino_id)
    color = DINO_PARAMS[dino_id]["color"]
    mat = create_material(f"dino_{dino_id}_skin", color, roughness=0.6)
    mesh_obj.data.materials.append(mat)
    export_glb(os.path.join(MODELS_DIR, f"dino_{dino_id}_skin.glb"), [mesh_obj], animations=False)
    render_preview(os.path.join(MODELS_DIR, f"dino_{dino_id}_skin_preview.png"))

def make_dino_rig(dino_id):
    clear_scene()
    mesh_obj = build_dino_mesh(dino_id)
    color = DINO_PARAMS[dino_id]["color"]
    mat = create_material(f"dino_{dino_id}_rig", color, roughness=0.6)
    mesh_obj.data.materials.append(mat)
    arm_obj = build_dino_armature(dino_id)
    parent_mesh_to_armature(mesh_obj, arm_obj)
    create_dino_actions(arm_obj, dino_id)
    export_glb(os.path.join(MODELS_DIR, f"dino_{dino_id}_rig.glb"), [arm_obj, mesh_obj], animations=True)
    render_preview(os.path.join(MODELS_DIR, f"dino_{dino_id}_rig_preview.png"))

def make_tools():
    for tool in TOOLS:
        clear_scene()
        bm = bmesh.new()
        if tool == "brush":
            add_cylinder(bm, 0.05, 0.6, (0, 0, 0.3), rotation=(0, 0, 0))
            add_cube(bm, 0.2, (0, 0, 0.6), scale=(1, 0.5, 0.2))
        elif tool == "pickaxe":
            add_cylinder(bm, 0.05, 0.8, (0, 0, 0.4), rotation=(0, 0, 0))
            add_cylinder(bm, 0.1, 0.4, (0, 0, 0.8), rotation=(0, math.radians(90), 0))
        elif tool == "detector":
            add_cube(bm, 0.3, (0, 0, 0.3), scale=(1, 0.5, 0.5))
            add_cylinder(bm, 0.03, 0.5, (0, 0, 0.6), rotation=(0, 0, 0))
            add_sphere(bm, 0.15, (0, 0, 0.9))
        elif tool == "camera":
            add_cube(bm, 0.3, (0, 0, 0.3), scale=(1, 0.6, 0.6))
            add_cylinder(bm, 0.1, 0.2, (0, 0.2, 0.3), rotation=(math.radians(90), 0, 0))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        mesh = bpy.data.meshes.new(f"tool_{tool}_mesh")
        bm.to_mesh(mesh)
        bm.free()
        obj = bpy.data.objects.new(f"tool_{tool}", mesh)
        bpy.context.collection.objects.link(obj)
        mat = create_material(f"tool_{tool}_mat", (0.5, 0.5, 0.5), roughness=0.7)
        obj.data.materials.append(mat)
        export_glb(os.path.join(MODELS_DIR, f"tool_{tool}.glb"), [obj], animations=False)
        render_preview(os.path.join(MODELS_DIR, f"tool_{tool}_preview.png"))

def make_excavation_layers():
    colors = {
        "desert": [(0.8, 0.6, 0.3), (0.7, 0.5, 0.2), (0.6, 0.4, 0.1)],
        "forest": [(0.3, 0.5, 0.2), (0.2, 0.4, 0.1), (0.1, 0.3, 0.05)],
        "ice": [(0.7, 0.8, 0.9), (0.6, 0.7, 0.8), (0.5, 0.6, 0.7)],
    }
    for biome in BIOMES:
        for layer in range(1, 4):
            clear_scene()
            bm = bmesh.new()
            add_cube(bm, 1.0, (0, 0, 0), scale=(2, 2, 0.2))
            for _ in range(5):
                x = random.uniform(-0.8, 0.8)
                y = random.uniform(-0.8, 0.8)
                z = random.uniform(-0.1, 0.1)
                add_sphere(bm, random.uniform(0.05, 0.15), (x, y, z))
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            mesh = bpy.data.meshes.new(f"soil_{biome}_layer{layer}_mesh")
            bm.to_mesh(mesh)
            bm.free()
            obj = bpy.data.objects.new(f"soil_{biome}_layer{layer}", mesh)
            bpy.context.collection.objects.link(obj)
            color = colors[biome][layer - 1]
            mat = create_material(f"soil_{biome}_layer{layer}_mat", color, roughness=0.9)
            obj.data.materials.append(mat)
            export_glb(os.path.join(MODELS_DIR, f"soil_{biome}_layer{layer}.glb"), [obj], animations=False)
            render_preview(os.path.join(MODELS_DIR, f"soil_{biome}_layer{layer}_preview.png"))

def make_museum_modules():
    for module in ["pedestal", "case", "sign"]:
        clear_scene()
        bm = bmesh.new()
        if module == "pedestal":
            add_cylinder(bm, 0.5, 0.2, (0, 0, 0.1))
            add_cylinder(bm, 0.3, 0.8, (0, 0, 0.5))
        elif module == "case":
            add_cube(bm, 1.0, (0, 0, 0.5), scale=(1, 1, 1))
        elif module == "sign":
            add_cube(bm, 0.8, (0, 0, 0.8), scale=(1, 0.1, 0.5))
            add_cylinder(bm, 0.05, 0.8, (0, 0, 0.4))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        mesh = bpy.data.meshes.new(f"museum_{module}_mesh")
        bm.to_mesh(mesh)
        bm.free()
        obj = bpy.data.objects.new(f"museum_{module}", mesh)
        bpy.context.collection.objects.link(obj)
        if module == "case":
            mat = create_material(f"museum_{module}_mat", (0.8, 0.9, 1.0), roughness=0.1, metallic=0.0)
            mat.blend_method = 'BLEND'
            bsdf = mat.node_tree.nodes.get("Principled BSDF")
            if bsdf:
                bsdf.inputs["Alpha"].default_value = 0.3
        else:
            mat = create_material(f"museum_{module}_mat", (0.6, 0.6, 0.6), roughness=0.5)
        obj.data.materials.append(mat)
        export_glb(os.path.join(MODELS_DIR, f"museum_{module}.glb"), [obj], animations=False)
        render_preview(os.path.join(MODELS_DIR, f"museum_{module}_preview.png"))

def make_hud_atlas():
    clear_scene()
    width, height = 512, 512
    img = bpy.data.images.new("hud_atlas", width, height)
    pixels = [0.1, 0.1, 0.1, 1.0] * (width * height)
    rects = [
        (10, 10, 100, 50, 0.8, 0.2, 0.2, 1.0),
        (120, 10, 100, 50, 0.2, 0.8, 0.2, 1.0),
        (230, 10, 100, 50, 0.2, 0.2, 0.8, 1.0),
        (10, 70, 320, 100, 0.5, 0.5, 0.5, 1.0),
        (10, 180, 150, 150, 0.9, 0.9, 0.2, 1.0),
        (170, 180, 150, 150, 0.2, 0.9, 0.9, 1.0),
    ]
    for (x, y, w, h, r, g, b, a) in rects:
        for yy in range(y, min(y + h, height)):
            for xx in range(x, min(x + w, width)):
                idx = (yy * width + xx) * 4
                pixels[idx] = r
                pixels[idx + 1] = g
                pixels[idx + 2] = b
                pixels[idx + 3] = a
    img.pixels.foreach_set(pixels)
    img.filepath_raw = os.path.join(UI_DIR, "hud_atlas.png")
    img.file_format = 'PNG'
    img.save()
    mat = create_material("hud_atlas_mat", (1, 1, 1))
    tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image = img
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        mat.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=1.0)
    mesh = bpy.data.meshes.new("hud_atlas_plane")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("hud_atlas", mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    export_glb(os.path.join(UI_DIR, "hud_atlas.glb"), [obj], animations=False)
    render_preview(os.path.join(UI_DIR, "hud_atlas_preview.png"))

def export_all():
    ensure_dirs()
    for dino_id in DINO_IDS:
        make_dino_skin(dino_id)
        make_dino_rig(dino_id)
    make_tools()
    make_excavation_layers()
    make_museum_modules()
    make_hud_atlas()
    print("All assets exported.")

if __name__ == "__main__":
    export_all()
