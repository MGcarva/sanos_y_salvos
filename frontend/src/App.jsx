import { BrowserRouter as Router, Routes, Route } from 'react-router-dom'
import { AuthProvider } from './contexts/AuthContext'
import Navbar from './components/Navbar'
import Footer from './components/Footer'
import PrivateRoute from './components/PrivateRoute'
import Home from './pages/Home'
import Login from './pages/Login'
import Register from './pages/Register'
import Mapa from './pages/Mapa'
import Reportar from './pages/Reportar'
import MisReportes from './pages/MisReportes'
import ReporteDetalle from './pages/ReporteDetalle'
import VerifyEmail from './pages/VerifyEmail'
import NotFound from './pages/NotFound'

function App() {
  return (
    <AuthProvider>
      <Router>
        <div className="d-flex flex-column min-vh-100">
          <Navbar />
          <main className="flex-grow-1">
            <Routes>
              <Route path="/" element={<Home />} />
              <Route path="/login" element={<Login />} />
              <Route path="/register" element={<Register />} />
              <Route path="/mapa" element={<Mapa />} />
              <Route path="/reporte/:id" element={<ReporteDetalle />} />
              <Route path="/verify-email" element={<VerifyEmail />} />
              <Route path="/reportar" element={<PrivateRoute><Reportar /></PrivateRoute>} />
              <Route path="/mis-reportes" element={<PrivateRoute><MisReportes /></PrivateRoute>} />
              <Route path="*" element={<NotFound />} />
            </Routes>
          </main>
          <Footer />
        </div>
      </Router>
    </AuthProvider>
  )
}

export default App
