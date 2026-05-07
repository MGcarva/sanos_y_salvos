import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import {
    PieChart, Pie, Cell, BarChart, Bar, XAxis, YAxis,
    CartesianGrid, Tooltip, Legend, ResponsiveContainer
} from 'recharts';
import { dashboardService } from '../services/services';

const COLORS_PIE = ['#e63946', '#2a9d8f'];
const RADIAN = Math.PI / 180;

const renderCustomLabel = ({ cx, cy, midAngle, innerRadius, outerRadius, percent }) => {
    if (percent < 0.05) return null;
    const radius = innerRadius + (outerRadius - innerRadius) * 0.5;
    const x = cx + radius * Math.cos(-midAngle * RADIAN);
    const y = cy + radius * Math.sin(-midAngle * RADIAN);
    return (
        <text x={x} y={y} fill="white" textAnchor="middle" dominantBaseline="central" fontSize={14} fontWeight="bold">
            {`${(percent * 100).toFixed(0)}%`}
        </text>
    );
};

export default function Estadisticas() {
    const [data, setData] = useState({ reportes: [], heatmap: [] });
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        dashboardService.get()
            .then(res => setData(res.data))
            .catch(() => setData({ reportes: [], heatmap: [] }))
            .finally(() => setLoading(false));
    }, []);

    const perdidos = data.reportes.filter(r => r.tipo === 'PERDIDO');
    const encontrados = data.reportes.filter(r => r.tipo === 'ENCONTRADO');

    // Pie: perdidas vs encontradas
    const pieData = [
        { name: 'Perdidas', value: perdidos.length },
        { name: 'Encontradas', value: encontrados.length }
    ].filter(d => d.value > 0);

    // Bar: por especie (apilado perdidas / encontradas)
    const especiesRaw = data.reportes.reduce((acc, r) => {
        const e = r.especie
            ? r.especie.charAt(0).toUpperCase() + r.especie.slice(1).toLowerCase()
            : 'Otra';
        if (!acc[e]) acc[e] = { name: e, Perdidas: 0, Encontradas: 0 };
        if (r.tipo === 'PERDIDO') acc[e].Perdidas++;
        else acc[e].Encontradas++;
        return acc;
    }, {});
    const especiesData = Object.values(especiesRaw)
        .sort((a, b) => (b.Perdidas + b.Encontradas) - (a.Perdidas + a.Encontradas));

    // Bar horizontal: zonas con más mascotas perdidas
    const locRaw = perdidos.reduce((acc, r) => {
        const loc = r.direccion?.split(',')[0]?.trim() || 'Sin ubicación';
        acc[loc] = (acc[loc] || 0) + 1;
        return acc;
    }, {});
    const locData = Object.entries(locRaw)
        .map(([name, value]) => ({ name, Cantidad: value }))
        .sort((a, b) => b.Cantidad - a.Cantidad)
        .slice(0, 8);

    if (loading) {
        return <div className="page-loading"><div className="spinner-border text-primary" role="status"></div></div>;
    }

    return (
        <div className="container py-4">
            {/* Header */}
            <div className="d-flex align-items-center gap-3 mb-4">
                <Link to="/" className="btn btn-outline-secondary btn-sm">
                    <i className="bi bi-arrow-left me-1"></i>Volver
                </Link>
                <div>
                    <h3 className="fw-bold mb-0 text-primary">
                        <i className="bi bi-bar-chart-fill me-2"></i>Estadísticas de Reportes
                    </h3>
                    <p className="text-muted mb-0">Análisis de {data.reportes.length} reportes activos</p>
                </div>
            </div>

            {/* Summary cards */}
            <div className="row g-3 mb-5">
                <div className="col-md-4">
                    <Link to="/perdidos" className="text-decoration-none">
                        <div className="card border-0 shadow-sm text-center p-3 h-100" style={{ borderTop: '4px solid #e63946' }}>
                            <div className="fw-bold text-danger" style={{ fontSize: '3rem' }}>{perdidos.length}</div>
                            <div className="text-muted fw-semibold">Mascotas Perdidas</div>
                            <small className="text-danger mt-1">Ver listado →</small>
                        </div>
                    </Link>
                </div>
                <div className="col-md-4">
                    <Link to="/encontrados" className="text-decoration-none">
                        <div className="card border-0 shadow-sm text-center p-3 h-100" style={{ borderTop: '4px solid #2a9d8f' }}>
                            <div className="fw-bold text-success" style={{ fontSize: '3rem' }}>{encontrados.length}</div>
                            <div className="text-muted fw-semibold">Mascotas Encontradas</div>
                            <small className="text-success mt-1">Ver listado →</small>
                        </div>
                    </Link>
                </div>
                <div className="col-md-4">
                    <div className="card border-0 shadow-sm text-center p-3 h-100" style={{ borderTop: '4px solid #4361ee' }}>
                        <div className="fw-bold text-primary" style={{ fontSize: '3rem' }}>{data.reportes.length}</div>
                        <div className="text-muted fw-semibold">Total Reportes Activos</div>
                        {data.reportes.length > 0 && (
                            <small className="text-muted mt-1">
                                {((encontrados.length / data.reportes.length) * 100).toFixed(0)}% resueltos
                            </small>
                        )}
                    </div>
                </div>
            </div>

            {data.reportes.length === 0 ? (
                <div className="empty-state">
                    <i className="bi bi-bar-chart"></i>
                    <h5>Sin datos suficientes para mostrar gráficos</h5>
                    <p>Los gráficos aparecerán una vez que haya reportes</p>
                    <Link to="/reportar" className="btn btn-primary">Crear primer reporte</Link>
                </div>
            ) : (
                <>
                    <div className="row g-4 mb-4">
                        {/* Pie Chart */}
                        <div className="col-md-5">
                            <div className="card border-0 shadow-sm h-100">
                                <div className="card-body">
                                    <h6 className="fw-bold mb-3">
                                        <i className="bi bi-pie-chart-fill me-2 text-primary"></i>
                                        Perdidas vs Encontradas
                                    </h6>
                                    <ResponsiveContainer width="100%" height={280}>
                                        <PieChart>
                                            <Pie
                                                data={pieData}
                                                cx="50%"
                                                cy="50%"
                                                outerRadius={110}
                                                dataKey="value"
                                                labelLine={false}
                                                label={renderCustomLabel}
                                            >
                                                {pieData.map((entry, index) => (
                                                    <Cell key={`cell-${index}`} fill={COLORS_PIE[index % COLORS_PIE.length]} />
                                                ))}
                                            </Pie>
                                            <Tooltip formatter={(value, name) => [value, name]} />
                                            <Legend />
                                        </PieChart>
                                    </ResponsiveContainer>
                                </div>
                            </div>
                        </div>

                        {/* Bar Chart: por especie */}
                        <div className="col-md-7">
                            <div className="card border-0 shadow-sm h-100">
                                <div className="card-body">
                                    <h6 className="fw-bold mb-3">
                                        <i className="bi bi-bar-chart me-2 text-primary"></i>
                                        Reportes por Especie
                                    </h6>
                                    {especiesData.length === 0 ? (
                                        <div className="text-center text-muted py-5">Sin datos</div>
                                    ) : (
                                        <ResponsiveContainer width="100%" height={280}>
                                            <BarChart data={especiesData} margin={{ top: 5, right: 10, left: 0, bottom: 5 }}>
                                                <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                                                <XAxis dataKey="name" tick={{ fontSize: 12 }} />
                                                <YAxis tick={{ fontSize: 12 }} allowDecimals={false} />
                                                <Tooltip />
                                                <Legend />
                                                <Bar dataKey="Perdidas" stackId="a" fill="#e63946" />
                                                <Bar dataKey="Encontradas" stackId="a" fill="#2a9d8f" radius={[4, 4, 0, 0]} />
                                            </BarChart>
                                        </ResponsiveContainer>
                                    )}
                                </div>
                            </div>
                        </div>
                    </div>

                    {/* Bar Chart horizontal: zonas */}
                    {locData.length > 0 && (
                        <div className="card border-0 shadow-sm mb-4">
                            <div className="card-body">
                                <h6 className="fw-bold mb-3">
                                    <i className="bi bi-geo-alt-fill me-2 text-danger"></i>
                                    Zonas con más mascotas perdidas
                                </h6>
                                <ResponsiveContainer width="100%" height={Math.max(200, locData.length * 40)}>
                                    <BarChart
                                        data={locData}
                                        layout="vertical"
                                        margin={{ top: 5, right: 30, left: 10, bottom: 5 }}
                                    >
                                        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" horizontal={false} />
                                        <XAxis type="number" tick={{ fontSize: 12 }} allowDecimals={false} />
                                        <YAxis type="category" dataKey="name" tick={{ fontSize: 12 }} width={160} />
                                        <Tooltip />
                                        <Bar dataKey="Cantidad" name="Mascotas perdidas" fill="#e63946" radius={[0, 4, 4, 0]} />
                                    </BarChart>
                                </ResponsiveContainer>
                            </div>
                        </div>
                    )}
                </>
            )}
        </div>
    );
}
