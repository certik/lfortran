submodule(separate_compilation_38a) separate_compilation_38b
    implicit none
contains
    module subroutine kernel(A, wksp)
        class(op_type), intent(in) :: A
        type(wksp_type), intent(inout) :: wksp
        call A%matvec(wksp%tmp(:,1), wksp%tmp(:,2))
    end subroutine
end submodule
