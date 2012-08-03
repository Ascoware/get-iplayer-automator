//
//  FourODTokenDecoder.m
//  Get_iPlayer GUI
//
//  Created by Thomas E. Willson on 8/1/12.
//
//

#import "FourODTokenDecoder.h"

@implementation FourODTokenDecoder
+ (NSString *)decodeToken:(NSString *)string
{
    PyObject *pName, *pModule, *pFunc;
    PyObject *pArgs, *pValue;
    NSString *result;
    
    
    Py_Initialize();
    pName = PyString_FromString([[[[NSBundle mainBundle] pathForResource:@"fourOD_token_decoder" ofType:@"py"] stringByDeletingLastPathComponent] cStringUsingEncoding:NSUTF8StringEncoding]);
    PySys_SetPath([[[[NSBundle mainBundle] pathForResource:@"fourOD_token_decoder" ofType:@"py"] stringByDeletingLastPathComponent] cStringUsingEncoding:NSUTF8StringEncoding]);
    /* Error checking of pName left out */
    
    pModule = PyImport_Import(PyString_FromString("fourOD_token_decoder"));
    Py_DECREF(pName);
    
    if (pModule != NULL) {
        pFunc = PyObject_GetAttrString(pModule, "Decode4odToken");
        /* pFunc is a new reference */
        
        if (pFunc && PyCallable_Check(pFunc)) {
            pArgs = PyTuple_New(1);
            PyTuple_SetItem(pArgs, 0, PyString_FromString([string cStringUsingEncoding:NSUTF8StringEncoding]));
            pValue = PyObject_CallObject(pFunc, pArgs);
            Py_DECREF(pArgs);
            if (pValue != NULL) {
                result = [NSString stringWithCString:PyString_AsString(pValue) encoding:NSUTF8StringEncoding];
                Py_DECREF(pValue);
            }
            else {
                Py_DECREF(pFunc);
                Py_DECREF(pModule);
                PyErr_Print();
                NSLog(@"Call failed\n");
                return nil;
            }
        }
        else {
            if (PyErr_Occurred())
                PyErr_Print();
            NSLog(@"Cannot find function \"%@\"\n", @"Decode4odToken");
        }
        Py_XDECREF(pFunc);
        Py_DECREF(pModule);
    }
    else {
        PyErr_Print();
        NSLog(@"Failed to load \"%@\"\n", @"Token Decoder File");
        return nil;
    }
    Py_Finalize();
    return result;
    
}
@end
