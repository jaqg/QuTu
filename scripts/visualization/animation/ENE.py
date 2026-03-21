# _____________________________________________________________________________
# *****************************************************************************
# Autor: José Antonio Quiñonero Gris
# Fecha de creación: 7 de febrero de 2022
# *****************************************************************************
# -----------------------------------------------------------------------------

# Animaciones de la particula en una caja unidimensional, bidimensional y
# tridimensional

# Librerias
import numpy as np
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import axes3d
import matplotlib.animation as animation
from matplotlib import cm
from math import factorial
from scipy.special import hermite

# Usar mi estilo para las graficas
plt.style.use('mine')

# *****************************************************************************
# INICIO
nombre_animacion = 'ENE_1.mp4'
# *****************************************************************************

# Ficheros de datos
fichero_datos_1                = '../data/in-doble_pozo_NH3.dat'
fichero_datos_2                = '../data/in-potencial.dat'
fichero_potencial              = '../data/out-potencial_cm-1.dat'
fichero_energias               = '../data/out-conver_energias_cm-1.dat'
fichero_funciones_pares        = '../data/out-funciones_pares_hartrees.dat'
fichero_funciones_impares      = '../data/out-funciones_impares_A.dat'
fichero_densidad_prob_pares    = '../data/out-densidad_prob_pares_A.dat'
fichero_densidad_prob_impares  = '../data/out-densidad_prob_impares_A.dat'
fichero_coeficientes_par       = '../data/out-coeficientes_par.dat'
fichero_coeficientes_impar     = '../data/out-coeficientes_par.dat'
fichero_puntos_corte           = '../data/out-puntos_corte.dat'
fichero_masa_red_alfa          = '../data/out-masa_red_alfa.dat'
# Apertura de ficheros, lectura de datos y definición de variables
N, xe_A, Vb_cm = np.loadtxt(fichero_datos_1, unpack=True, skiprows=1)
xmin, xmax, dx = np.loadtxt(fichero_datos_2, unpack=True, skiprows=1)
x_A, V_cm = np.loadtxt(fichero_potencial, unpack=True, skiprows=2)
n_fich, Nconver, Econver, E_cm = np.loadtxt(fichero_energias, unpack=True, skiprows=1)
x_par, Phi0_f, Phi2_f, Phi4_f = np.loadtxt(fichero_funciones_pares, unpack=True, skiprows=2)
# x_impar, Phi1, Phi3, Phi5 = np.loadtxt(fichero_funciones_impares, unpack=True, skiprows=2)
# x_dpar, dPhi0, dPhi2, dPhi4 = np.loadtxt(fichero_densidad_prob_pares, unpack=True, skiprows=2)
# x_dimpar, dPhi1, dPhi3, dPhi5 = np.loadtxt(fichero_densidad_prob_impares, unpack=True, skiprows=2)
n_par, cPhi0, cPhi2, cPhi4  = np.loadtxt(fichero_coeficientes_par, unpack=True, skiprows=1)
n_impar, cPhi1, cPhi3, cPhi5  = np.loadtxt(fichero_coeficientes_impar, unpack=True, skiprows=1)
alfa_grad_arr, E_alfa, pcx1, pcx2, pcx3, pcx4 = np.loadtxt(fichero_puntos_corte, unpack=True, skiprows=3)
mu, alfa_a0, alfa_A = np.loadtxt(fichero_masa_red_alfa,unpack=True, skiprows=1)

# Factores de conversión
RBOHR=0.529177210903      # angstrom
EUACM=2.1947463136320E+05 # hartrees -> cm-1
EHAJ=4.3597447222071E-18  # hartrees -> J
HP=6.62607015E-34         # Constante de Planck en J·s
CLUZ=29979245800          # Velocidad de la luz en cm/s
hbar_J=HP/(2*np.pi)       # Constante de Planck reducida en J·s
hbar_ha = 1
m_AU = mu
# Energías de los estados estacionarios en hartrees
E_ha = E_cm/EUACM
V_ha = V_cm/EUACM
x_a0 = x_A/RBOHR
E0_ha = E_ha[0]
E1_ha = E_ha[1]
E2_ha = E_ha[2]
E3_ha = E_ha[3]

# Parámetros xe y Vb en unidades atomicas
xe_a0 = xe_A/RBOHR
Vb_ha = Vb_cm/EUACM
# print((6*m_AU*Vb_ha/(hbar_ha**2*xe_a0**4))
# Valores propios de la energia en hartrees
def Eoa(n):
    res = (n + 1/2) * hbar_ha**2*alfa_a0/m_AU
    return res
# Variable de desplazamiento xi en a0
def xi(x):
    return np.sqrt(alfa_a0) * x
# Constante de normalizacion en a0^1/4
def N(n):
    return ( np.sqrt(alfa_a0/np.pi) * (1/(2**n * factorial(n))) )**(1/2)
# Funcion exponencial
def expo(x):
    return np.exp(-(xi(x)**2)/2)
# Polinomios de Hermite
def Hv(n,x):
    herm = hermite(n)
    P_v = herm(x)
    return P_v
# Componente temporal de funciones
def time_expo(n,t):
    return np.exp(-1j * Eoa(n) * t/hbar_ha)
# Funciones propias
# def phi(n,x,t,alfa):
#     return N(n) * expo(x) * Hv(n,x) * time_expo(n,t)
# Densidad de probabilidad
def dens_phi(n,x,t):
    return np.conj(phi(n,x,t)) * phi(n,x,t)
# Funciones propias
def phi(n,x,t,alfa):
    N         = (alfa/np.pi)**0.25/np.sqrt(2**n*factorial(n))
    expo      = np.exp(-alfa*x**2/2)
    time_expo = np.exp(-1j * Eoa(n) * t/hbar_ha)
    return N * expo * Hv(n,x) * time_expo

# fig, ax = plt.subplots()
# # m_AU = 1
# # alfa_a0 = 1
# for n in range(3):
#     ax.plot(x_a0,phi(n,x_a0,0,alfa_a0).real)
# plt.show()

### -- FUNCIONES DE PRUEBA -- ###
limite=0.01
# for i in np.arange(0,len(cPhi0)):
#     if abs(cPhi0[i])>limite:
#         print(i, cPhi0[i])
def Phi0(x,t,alfa):
    res = 0
    for i in np.arange(0,len(cPhi0)):
        if abs(cPhi0[i])>limite:
            res = -cPhi0[i] * phi(2*i,x,t,alfa) + res
    res = res
    return res
def dPhi0(x,t,alfa):
    res = np.conj(Phi0(x,t,alfa)) * (Phi0(x,t,alfa))
    return res

fig, ax = plt.subplots()
# m_AU = 1
# alfa_a0 = 9.7596120034399210
ax.plot(x_a0,Phi0(x_a0,0,alfa_a0).real)
ax.plot(x_par,Phi0_f)
plt.show()
