program intrinsics_34
integer, parameter :: dp = kind(0.d0)
real :: x = 3.143
real(dp) :: y = 2.33_dp
print *, tiny(x), epsilon(x)
print *, tiny(y), epsilon(y)
end program
