/**
 * This logicle implementation is based on Java reference
 * implementation that is part of the full Gating-ML 2.0
 * specification. The Java reference implementation has
 * been provided by Wayne Moore. Josef Spidlen ported it to C/CPP and
 * integrated it with R/flowCore. Rachel Finck integrated
 * it with MATLAB.
 *
 *  Reference:   B. Ellis, P. Haaland, F. Hahne, N. Le Meur, N.
 *           Gopalakrishnan and J.Splidlen. flowCore: Basic structures
 *           for flow cytometry data. R package version 1.28.0.
 *
 * The Logicle method is patented under United States Patent 6,954,722.
 * However, Stanford University does not enforce the patent for non-profit
 * academic purposes or for commercial use in the field of flow cytometry.
 */

#include <iostream>
#include "logicle.h"
extern "C" {
#include "mex.h"
    
    /* Input and Output Arguments */
#define	x_in	prhs[0]
#define	T_in	prhs[1]
#define	W_in	prhs[2]
#define	M_in	prhs[3]
#define	A_in	prhs[4]
    
#define	y_out	plhs[0]
    
    static void logicle_here( double y[], double x[], double T[], double W[], double M[], double A[], size_t size_m, size_t size_n)
    {
        try{
        Logicle *lg = new Logicle(T[0], W[0], M[0], A[0]);
        for (int i = 0; i < size_m*size_n; i++) {
             y[i] = lg->inverse(x[i]) ; 
            
        }
        if (lg != NULL) delete lg;
        }
        catch(const char *str){
            mexErrMsgTxt(str);
        }
        return;
    }
    
    void mexFunction( int nlhs, mxArray *plhs[],
            int nrhs, const mxArray *prhs[] )
            
    {
        
        double *x,*y;
        double *T,*W,*M,*A;
        size_t m,n;
        
        if (nrhs != 5) {
            mexErrMsgIdAndTxt( "MATLAB:c_test:invalidNumInputs",
                    "Five input arguments required.");
        } else if (nlhs > 1) {
            mexErrMsgIdAndTxt( "MATLAB:c_test:maxlhs",
                    "Too many output arguments.");
        }
        
        m = mxGetM(x_in);
        n = mxGetN(x_in);
        
        /* Create a matrix for the return argument */
        y_out = mxCreateDoubleMatrix( (mwSize)m, (mwSize)n, mxREAL);
        
        y = mxGetPr(y_out);
        x = mxGetPr(x_in);
        T = mxGetPr(T_in);
        W = mxGetPr(W_in);
        M = mxGetPr(M_in);
        A = mxGetPr(A_in);
        
        logicle_here(y,x,T,W,M,A,m,n);
        return;
        
    }   
    
}// end of extern c

