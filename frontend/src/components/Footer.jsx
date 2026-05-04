import { Link } from 'react-router-dom';

export default function Footer() {
    return (
        <footer className="footer">
            <div className="container">
                <div className="row">
                    <div className="col-md-4 mb-3">
                        <h5 className="text-white fw-bold">
                            <i className="bi bi-heart-pulse-fill me-2"></i>
                            Sanos y Salvos
                        </h5>
                        <p className="small">
                            Plataforma comunitaria para reunir mascotas perdidas con sus familias.
                            Juntos podemos hacer la diferencia.
                        </p>
                    </div>
                    <div className="col-md-2 mb-3">
                        <h6 className="text-white fw-bold mb-3">Navegación</h6>
                        <ul className="list-unstyled">
                            <li className="mb-1"><Link to="/">Inicio</Link></li>
                            <li className="mb-1"><Link to="/mapa">Mapa</Link></li>
                            <li className="mb-1"><Link to="/reportar">Reportar</Link></li>
                        </ul>
                    </div>
                    <div className="col-md-3 mb-3">
                        <h6 className="text-white fw-bold mb-3">Recursos</h6>
                        <ul className="list-unstyled">
                            <li className="mb-1"><Link to="/register">Crear cuenta</Link></li>
                            <li className="mb-1"><Link to="/mis-reportes">Mis reportes</Link></li>
                        </ul>
                    </div>
                    <div className="col-md-3 mb-3">
                        <h6 className="text-white fw-bold mb-3">Contacto</h6>
                        <ul className="list-unstyled small">
                            <li className="mb-1"><i className="bi bi-envelope me-2"></i>info@sanosysalvos.com</li>
                            <li className="mb-1"><i className="bi bi-geo-alt me-2"></i>Bogotá, Colombia</li>
                        </ul>
                    </div>
                </div>
                <hr className="border-secondary" />
                <div className="text-center small pb-2">
                    <span className="opacity-50">© 2026 Sanos y Salvos. Todos los derechos reservados.</span>
                </div>
            </div>
        </footer>
    );
}
