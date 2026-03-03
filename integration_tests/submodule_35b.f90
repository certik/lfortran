module submodule_35_mod
  implicit none
  interface operator(.det.)
    pure module function pure_det(a) result(det)
      real(8), intent(in) :: a(:,:)
      real(8) :: det
    end function
  end interface operator(.det.)
end module submodule_35_mod
