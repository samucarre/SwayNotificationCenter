namespace SwayNotificationCenter {
    /**
     * «Cajón» (WayBian, 3-nov-2026): el centro de notificaciones se abre como los paneles de la barra, dibujado
     * escalado en vertical desde su borde de arriba (pegado a la barra) con un vaivén suave: scaleY 0,12 → 1,05 → 1
     * en 0,7 s, cubic-bezier(.33,.9,.35,1) en cada tramo. Solo cambia el dibujo: la distribución y los clics no se tocan.
     */
    public class Cajon : Gtk.Widget {
        private Gtk.Widget ? hijo = null;
        private double escala = 1.0;
        private int64 t0 = 0;
        private int64 t_prev = 0;
        private uint tick = 0;
        private const double DURACION = 0.7;

        public Cajon (Gtk.Widget hijo) {
            this.hijo = hijo;
            hijo.set_parent (this);
        }

        public override void measure (Gtk.Orientation orientation, int for_size,
                                      out int minimum, out int natural,
                                      out int minimum_baseline, out int natural_baseline) {
            hijo.measure (orientation, for_size, out minimum, out natural,
                          out minimum_baseline, out natural_baseline);
        }

        public override void size_allocate (int width, int height, int baseline) {
            hijo.allocate (width, height, baseline, null);
        }

        public override void snapshot (Gtk.Snapshot snapshot) {
            if (escala >= 1.0) {
                snapshot_child (hijo, snapshot);
                return;
            }
            snapshot.save ();
            snapshot.scale (1.0f, (float) (escala > 0 ? escala : 0.0001));
            snapshot_child (hijo, snapshot);
            snapshot.restore ();
        }

        public override void dispose () {
            if (tick != 0) {
                remove_tick_callback (tick);
                tick = 0;
            }
            if (hijo != null) {
                hijo.unparent ();
                hijo = null;
            }
            base.dispose ();
        }

        /** Arranca la apertura elástica (al hacer visible la ventana; los ticks corren en cuanto está mapeada). */
        public void abrir () {
            unowned Gtk.Settings ? ajustes = Gtk.Settings.get_default ();
            if (ajustes != null && !ajustes.gtk_enable_animations) {
                escala = 1.0;
                queue_draw ();
                return;
            }
            escala = 0.12;
            t0 = 0;
            t_prev = 0;
            if (tick != 0) {
                remove_tick_callback (tick);
            }
            tick = add_tick_callback ((widget, clock) => {
                int64 t = clock.get_frame_time ();
                if (t0 == 0) {
                    t0 = t;
                    t_prev = t;
                }
                // Un parón del bucle (la creación de las ventanas en blanco de las otras pantallas al mapearse,
                // >80 ms) no se descuenta de la animación: se desplaza el origen y el cajón sigue donde estaba,
                // en vez de saltar al final sin que se vea ningún fotograma.
                if (t - t_prev > 80000) {
                    t0 += (t - t_prev) - 16000;
                }
                t_prev = t;
                double p = (double) (t - t0) / 1e6 / DURACION;
                escala = escala_suave (p);
                queue_draw ();
                if (p >= 1.0) {
                    tick = 0;
                    escala = 1.0;
                    return GLib.Source.REMOVE;
                }
                return GLib.Source.CONTINUE;
            });
            queue_draw ();
        }

        /** y de una cubic-bezier de CSS (p1=(x1,y1), p2=(x2,y2)) para la abscisa x∈[0,1]. */
        private static double bezier (double x, double x1, double y1, double x2, double y2) {
            if (x <= 0) {
                return 0.0;
            }
            if (x >= 1) {
                return 1.0;
            }
            double lo = 0.0, hi = 1.0, t = x;
            for (int i = 0; i < 24; i++) {
                double xe = 3 * (1 - t) * (1 - t) * t * x1 + 3 * (1 - t) * t * t * x2 + t * t * t;
                double d = xe - x;
                if (d < 0) {
                    d = -d;
                }
                if (d < 1e-4) {
                    break;
                }
                if (xe < x) {
                    lo = t;
                } else {
                    hi = t;
                }
                t = (lo + hi) / 2;
            }
            return 3 * (1 - t) * (1 - t) * t * y1 + 3 * (1 - t) * t * t * y2 + t * t * t;
        }

        /** scaleY 0,12 → 1,05 → 1: los dos tramos del vaivén «suave» (p = progreso 0..1). */
        private static double escala_suave (double p) {
            if (p >= 1) {
                return 1.0;
            }
            if (p < 0.6) {
                return 0.12 + (1.05 - 0.12) * bezier (p / 0.6, 0.33, 0.9, 0.35, 1);
            }
            return 1.05 + (1.0 - 1.05) * bezier ((p - 0.6) / 0.4, 0.33, 0.9, 0.35, 1);
        }
    }
}
