#ifndef ANTIALIASING_COMMON_INCLUDED
#define ANTIALIASING_COMMON_INCLUDED

#define TEMPLATE_5_FLT(FunctionName, Parameter1, Parameter2, Parameter3, Parameter4, Parameter5, FunctionBody) \
float FunctionName(float Parameter1, float Parameter2, float Parameter3, float Parameter4, float Parameter5) { FunctionBody; }

TEMPLATE_5_FLT(Max5, a, b, c, d, e, return max(max(max(max(a, b), c), d), e))
TEMPLATE_5_FLT(Min5, a, b, c, d, e, return min(min(min(min(a, b), c), d), e))

#endif
