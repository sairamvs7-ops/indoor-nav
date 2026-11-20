declare module 'js-aruco' {
  export namespace AR {
    export class Detector {
      detect(imageData: ImageData): Marker[];
    }
    export interface Marker {
      id: number;
      corners: { x: number; y: number }[];
    }
  }
}
