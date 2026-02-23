interface Point3D {
  x: number;
  y: number;
  z: number;
  screenX?: number;
  screenY?: number;
}

interface Face {
  vertices: number[];
  centroid: Point3D;
  normal: Point3D;
  transform: {
    normal: Point3D;
    centroid: Point3D;
  };
}

interface Light {
  x: number;
  y: number;
  z: number;
  r: number;
  g: number;
  b: number;
}

interface CrystalOptions {
  width: number;
  height: number;
  onRender?: () => void;
}

const ICOSAHEDRON_VERTICES: Point3D[] = [
  { x: 0.550563524346, y: 0.758024984088, z: -0.349682612032 },
  { x: 0.62319582135, y: 0.436643142534, z: 0.648821804759 },
  { x: 0.975676690271, y: -0.177816333299, z: -0.12820432003 },
  { x: -0.32007250628, y: 0.0780544757795, z: 0.944172171553 },
  { x: 0.437594031513, y: -0.598061218782, z: 0.671441912732 },
  { x: 0.32007250628, y: -0.0780544757795, z: -0.944172171553 },
  { x: 0.250253520018, y: -0.916161840828, z: -0.313082508502 },
  { x: -0.437594031513, y: 0.598061218782, z: -0.671441912732 },
  { x: -0.62319582135, y: -0.436643142534, z: -0.648821804759 },
  { x: -0.250253520018, y: 0.916161840828, z: 0.313082508502 },
  { x: -0.975676690271, y: 0.177816333299, z: 0.12820432003 },
  { x: -0.550563524346, y: -0.758024984088, z: 0.349682612032 },
];

const ICOSAHEDRON_FACES: number[][] = [
  [0, 1, 2], [1, 3, 4], [0, 2, 5], [2, 4, 6], [0, 5, 7],
  [5, 6, 8], [0, 7, 9], [7, 8, 10], [0, 9, 1], [9, 10, 3],
  [4, 2, 1], [11, 4, 3], [6, 5, 2], [11, 6, 4], [8, 7, 5],
  [11, 8, 6], [10, 9, 7], [11, 10, 8], [3, 1, 9], [11, 3, 10],
];

function matrixMultiply(a: number[][], b: number[][]): number[][] {
  const matrix: number[][] = [[0, 0, 0], [0, 0, 0], [0, 0, 0]];
  for (let i = 0; i < 3; i++) {
    for (let j = 0; j < 3; j++) {
      for (let k = 0; k < 3; k++) {
        matrix[i][j] += a[i][k] * b[k][j];
      }
    }
  }
  return matrix;
}

function rotate(point: Point3D, r: number[][]): Point3D {
  return {
    x: point.x * r[0][0] + point.y * r[0][1] + point.z * r[0][2],
    y: point.x * r[1][0] + point.y * r[1][1] + point.z * r[1][2],
    z: point.x * r[2][0] + point.y * r[2][1] + point.z * r[2][2],
  };
}

function computeCentroid(vertices: Point3D[]): Point3D {
  const centroid = { x: 0, y: 0, z: 0 };
  for (const v of vertices) {
    centroid.x += v.x;
    centroid.y += v.y;
    centroid.z += v.z;
  }
  return {
    x: centroid.x / vertices.length,
    y: centroid.y / vertices.length,
    z: centroid.z / vertices.length,
  };
}

function computeNormal(v0: Point3D, v1: Point3D, v2: Point3D, centroid: Point3D): Point3D {
  const a = { x: v1.x - v0.x, y: v1.y - v0.y, z: v1.z - v0.z };
  const b = { x: v2.x - v0.x, y: v2.y - v0.y, z: v2.z - v0.z };
  let normal = {
    x: a.y * b.z - a.z * b.y,
    y: a.z * b.x - a.x * b.z,
    z: a.x * b.y - a.y * b.x,
  };
  const magnitude = Math.sqrt(normal.x * normal.x + normal.y * normal.y + normal.z * normal.z);
  normal = { x: normal.x / magnitude, y: normal.y / magnitude, z: normal.z / magnitude };
  const flip = normal.x * centroid.x + normal.y * centroid.y + normal.z * centroid.z < 0;
  if (flip) {
    normal.x = -normal.x;
    normal.y = -normal.y;
    normal.z = -normal.z;
  }
  return normal;
}

function normalize(v: Point3D): Point3D {
  const len = Math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
  return { x: v.x / len, y: v.y / len, z: v.z / len };
}

export class CrystalEngine {
  private canvas: HTMLCanvasElement;
  private ctx: CanvasRenderingContext2D;
  private width: number;
  private height: number;
  private vertices: Point3D[] = [];
  private faces: Face[] = [];
  private r: number[][] = [[1, 0, 0], [0, 1, 0], [0, 0, 1]];
  private scale: number;
  private distance = 4;
  private yaw = 0.02;
  private pitch = 0.01;
  private minRotation = 0.0001;
  private lights: Light[] = [];
  private dragging = false;
  private lastPoint: { x: number; y: number } | null = null;
  private animationId: number | null = null;
  private onRender?: () => void;
  private isDark = false;

  constructor(canvas: HTMLCanvasElement, options: CrystalOptions) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d')!;
    this.width = options.width;
    this.height = options.height;
    this.scale = this.width * (4 / 3);
    this.onRender = options.onRender;

    this.initGeometry();
    this.lights = [{ ...normalize({ x: -5, y: -5, z: 20 }), r: 140, g: 140, b: 140 }];
    this.setupInteraction();
    this.start();
  }

  private initGeometry() {
    this.vertices = JSON.parse(JSON.stringify(ICOSAHEDRON_VERTICES));

    this.faces = ICOSAHEDRON_FACES.map((faceVerts) => {
      const verts = faceVerts.map((i) => this.vertices[i]);
      const centroid = computeCentroid(verts);
      const normal = computeNormal(verts[0], verts[1], verts[2], centroid);
      return {
        vertices: faceVerts,
        centroid,
        normal,
        transform: { normal: { x: 0, y: 0, z: 0 }, centroid: { x: 0, y: 0, z: 0 } },
      };
    });
  }

  private setupInteraction() {
    const handler = (e: MouseEvent | TouchEvent) => {
      const rect = this.canvas.getBoundingClientRect();
      let clientX: number, clientY: number;

      if ('touches' in e) {
        if (e.touches.length !== 1) return;
        clientX = e.touches[0].clientX;
        clientY = e.touches[0].clientY;
      } else {
        clientX = e.clientX;
        clientY = e.clientY;
      }

      const x = clientX - rect.left;
      const y = clientY - rect.top;

      this.dragging = true;
      this.lastPoint = { x, y };

      const moveHandler = (ev: MouseEvent | TouchEvent) => {
        let cx: number, cy: number;
        if ('touches' in ev) {
          cx = ev.touches[0].clientX;
          cy = ev.touches[0].clientY;
        } else {
          cx = ev.clientX;
          cy = ev.clientY;
        }

        const bounds = this.canvas.getBoundingClientRect();
        const mx = cx - bounds.left;
        const my = cy - bounds.top;

        const depth = this.scale / this.distance / 4;
        this.yaw = Math.atan2(this.lastPoint!.x - this.width / 4, depth) - Math.atan2(mx - this.width / 4, depth);
        this.pitch = Math.atan2(this.lastPoint!.y - this.height / 4, depth) - Math.atan2(my - this.height / 4, depth);
        this.lastPoint = { x: mx, y: my };
      };

      const upHandler = () => {
        this.dragging = false;
        this.lastPoint = null;
        window.removeEventListener('mousemove', moveHandler);
        window.removeEventListener('mouseup', upHandler);
        window.removeEventListener('touchmove', moveHandler);
        window.removeEventListener('touchend', upHandler);
      };

      window.addEventListener('mousemove', moveHandler);
      window.addEventListener('mouseup', upHandler);
      window.addEventListener('touchmove', moveHandler, { passive: false });
      window.addEventListener('touchend', upHandler);
    };

    this.canvas.addEventListener('mousedown', handler);
    this.canvas.addEventListener('touchstart', handler, { passive: true });
  }

  setDarkMode(dark: boolean) {
    this.isDark = dark;
  }

  private transformVertices() {
    for (const vertex of this.vertices) {
      const rotated = rotate(vertex, this.r);
      vertex.screenX = this.width / 2 + (this.scale * rotated.x) / (this.distance - rotated.z);
      vertex.screenY = this.height / 2 + (this.scale * rotated.y) / (this.distance - rotated.z);
    }
  }

  private transformFaces() {
    for (const face of this.faces) {
      face.transform.normal = rotate(face.normal, this.r);
      face.transform.centroid = rotate(face.centroid, this.r);
    }
  }

  private sortByNormal(): number[] {
    const order = this.faces.map((_, i) => i);
    order.sort((a, b) => {
      const delta = this.faces[b].transform.normal.z - this.faces[a].transform.normal.z;
      return delta > 0 ? -1 : delta < 0 ? 1 : 0;
    });
    return order;
  }

  private computeLighting(normal: Point3D): string {
    let r = 0, g = 0, b = 0;
    for (const light of this.lights) {
      const cos = normal.x * light.x + normal.y * light.y + normal.z * light.z;
      r = Math.max(0, Math.min(255, Math.round(r + cos * light.r)));
      g = Math.max(0, Math.min(255, Math.round(g + cos * light.g)));
      b = Math.max(0, Math.min(255, Math.round(b + cos * light.b)));
    }

    const bg = this.isDark ? 30 : 255;
    const fg = this.isDark ? 255 : 30;

    const blendedR = Math.round(r * 0.9 + bg * 0.1);
    const blendedG = Math.round(g * 0.9 + bg * 0.1);
    const blendedB = Math.round(b * 0.9 + bg * 0.1);

    return `rgb(${blendedR}, ${blendedG}, ${blendedB})`;
  }

  private render() {
    this.ctx.clearRect(0, 0, this.width, this.height);

    this.transformVertices();
    this.transformFaces();

    const order = this.sortByNormal();

    for (const i of order) {
      const face = this.faces[i];
      const isBackface = face.transform.normal.z <= 0;

      if (!isBackface) {
        const color = this.computeLighting(face.transform.normal);
        this.ctx.strokeStyle = color;
        this.ctx.fillStyle = color;
        this.ctx.lineWidth = 0.5;
        this.ctx.beginPath();

        for (let j = 0; j < face.vertices.length; j++) {
          const vertex = this.vertices[face.vertices[j]];
          if (j === 0) {
            this.ctx.moveTo(vertex.screenX!, vertex.screenY!);
          } else {
            this.ctx.lineTo(vertex.screenX!, vertex.screenY!);
          }
        }
        this.ctx.closePath();
        this.ctx.fill();
        this.ctx.stroke();
      }
    }

    this.onRender?.();
  }

  private animate() {
    const minYaw = 0.02;
    const minPitch = 0.015;
    
    if (this.dragging) {
      // When dragging, don't update rotation values
    } else {
      // First update rotation values
      this.yaw = minYaw + Math.sin(Date.now() / 1500) * 0.008;
      this.pitch = minPitch + Math.cos(Date.now() / 2000) * 0.005;
    }
    
    // Then apply rotation
    const rotationMatrix = matrixMultiply(
      [[Math.cos(this.yaw), 0, -Math.sin(this.yaw)], [0, 1, 0], [Math.sin(this.yaw), 0, Math.cos(this.yaw)]],
      this.r
    );
    this.r = matrixMultiply(
      [[1, 0, 0], [0, Math.cos(this.pitch), -Math.sin(this.pitch)], [0, Math.sin(this.pitch), Math.cos(this.pitch)]],
      rotationMatrix
    );

    this.render();
  }

  start() {
    if (this.animationId === null) {
      this.animationId = window.setInterval(() => this.animate(), 20) as unknown as number;
    }
  }

  stop() {
    if (this.animationId !== null) {
      clearInterval(this.animationId);
      this.animationId = null;
    }
  }

  destroy() {
    this.stop();
  }
}
