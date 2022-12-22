program intrinsics_34
integer, parameter :: dp = kind(0.d0)
real :: x = 3.143
real(dp) :: y = 2.33_dp
print *, tiny(x), epsilon(x)
print *, tiny(y), epsilon(y)
!if (abs(tiny(x) - 1.17549435E-38) > 1e-

!   1.17549435E-38   1.19209290E-07
!   2.2250738585072014E-308   2.2204460492503131E-016

end program
